defmodule Jido.Connect.MCP.Session do
  @moduledoc """
  Host-owned notification session for an authorized MCP endpoint.

  Start this process under the host supervisor. Pass the same `:context`,
  `:credential_lease`, and `:policy` options used for Connect operations.
  `:subscriber` defaults to the caller. Events arrive as
  `{:jido_connect_mcp, session, method, sanitized_params}`.

  The immutable filter supports toolsListChanged, resourcesListChanged,
  promptsListChanged, and resourceSubscriptions. Each selected capability is
  authorized before the session opens. Modern streams require MCP 2026-07-28.
  ExMCP owns acknowledgment, reconnect, and protocol state. The session checks
  the endpoint lease before each event and stops when the lease is retired.
  Hosts must fence a connection when policy or credentials change.

  This API returns a local process, not a serializable catalog result. No
  credential material is retained in session state. Close the session before
  stopping a host-owned client. Connect never stops a host-owned client.
  """

  use GenServer
  alias Jido.Connect.{Authorization, Context, CredentialLease, Error, Sanitizer}
  alias Jido.Connect.MCP.{EndpointLeaseManager, EndpointResolver, ExMCPClient}

  @keys ~w(toolsListChanged resourcesListChanged promptsListChanged resourceSubscriptions)

  def start_link(endpoint_id, filter, opts) when is_list(opts) do
    owner = Keyword.get(opts, :subscriber, self())

    with :ok <- validate_timeout(Keyword.get(opts, :timeout, 5_000)),
         :ok <- validate(endpoint_id, filter, owner),
         :ok <- authorize(endpoint_id, filter, opts) do
      GenServer.start_link(__MODULE__, {endpoint_id, filter, opts, owner})
    end
  end

  def child_spec({endpoint_id, filter, opts}) do
    %{
      id: {__MODULE__, endpoint_id},
      start: {__MODULE__, :start_link, [endpoint_id, filter, opts]},
      restart: :temporary
    }
  end

  @doc "Closes the notification stream and releases its endpoint lease."
  def close(session), do: GenServer.stop(session, :normal)

  @doc "Returns only public session state."
  def status(session), do: GenServer.call(session, :status)

  @impl true
  def init({endpoint_id, filter, opts, owner}) do
    Process.flag(:trap_exit, true)

    with :ok <- validate_timeout(Keyword.get(opts, :timeout, 5_000)),
         :ok <- validate(endpoint_id, filter, owner),
         :ok <- authorize(endpoint_id, filter, opts),
         {:ok, token} <- EndpointResolver.resolve_lease(endpoint_id, opts) do
      case open(token, filter, Keyword.get(opts, :timeout, 5_000)) do
        {:ok, subscription} ->
          Process.send_after(self(), :check_lease, 100)

          {:ok,
           %{
             endpoint_id: endpoint_id,
             token: token,
             subscription: subscription,
             owner: owner,
             monitor: Process.monitor(owner),
             subscription_monitor: Process.monitor(subscription.pid)
           }}

        {:error, error} ->
          release(token)
          {:stop, error}
      end
    else
      {:error, error} -> {:stop, error}
    end
  end

  @impl true
  def handle_call(:status, _from, state) do
    {:reply, %{endpoint_id: state.endpoint_id, status: :active}, state}
  end

  @impl true
  def handle_info({:ex_mcp_subscription, subscription, method, params}, state) do
    if same_subscription?(subscription, state.subscription) do
      case dispatchable(state.token) do
        :ok ->
          send(state.owner, {:jido_connect_mcp, self(), method, Sanitizer.sanitize(params)})
          {:noreply, state}

        {:error, _} ->
          {:stop, :normal, state}
      end
    else
      {:noreply, state}
    end
  end

  def handle_info({:ex_mcp_subscription_resync, subscription, {:complete, snapshot}}, state) do
    if same_subscription?(subscription, state.subscription) do
      case dispatchable(state.token) do
        :ok ->
          send(state.owner, {:jido_connect_mcp, self(), :resync, Sanitizer.sanitize(snapshot)})
          {:noreply, state}

        {:error, _} ->
          {:stop, :normal, state}
      end
    else
      {:noreply, state}
    end
  end

  def handle_info({:ex_mcp_subscription_closed, subscription, _reason}, state) do
    if same_subscription?(subscription, state.subscription),
      do: {:stop, :normal, state},
      else: {:noreply, state}
  end

  def handle_info(:check_lease, state) do
    case dispatchable(state.token) do
      :ok ->
        Process.send_after(self(), :check_lease, 100)
        {:noreply, state}

      {:error, _} ->
        {:stop, :normal, state}
    end
  end

  def handle_info({:DOWN, monitor, :process, _pid, _reason}, %{monitor: monitor} = state),
    do: {:stop, :normal, state}

  def handle_info(
        {:DOWN, monitor, :process, _pid, _reason},
        %{subscription_monitor: monitor} = state
      ),
      do: {:stop, :normal, state}

  def handle_info({:EXIT, _pid, _reason}, state), do: {:stop, :normal, state}
  def handle_info(_message, state), do: {:noreply, state}

  @impl true
  def terminate(_reason, state) do
    ExMCPClient.close_subscription(state.subscription)
    release(state.token)
  end

  @impl true
  def format_status(_reason, [_pdict, state]), do: [data: [endpoint_id: state.endpoint_id]]

  defp validate_timeout(value) when is_integer(value) and value in 1..120_000, do: :ok

  defp validate_timeout(_),
    do: {:error, Error.validation("Invalid MCP session timeout", reason: :invalid_timeout)}

  defp validate(endpoint, filter, owner) do
    valid? =
      is_binary(endpoint) and endpoint != "" and is_pid(owner) and is_map(filter) and
        map_size(filter) > 0 and
        Enum.all?(filter, fn
          {"resourceSubscriptions", uris} when is_list(uris) ->
            length(uris) <= 100 and Enum.all?(uris, &(is_binary(&1) and byte_size(&1) in 1..4096))

          {key, value} ->
            key in @keys and key != "resourceSubscriptions" and is_boolean(value)
        end)

    if valid?,
      do: :ok,
      else:
        {:error, Error.validation("Invalid MCP notification filter", reason: :invalid_mcp_filter)}
  end

  defp authorize(endpoint, filter, opts) do
    with %Context{} = context <- Keyword.get(opts, :context),
         %CredentialLease{} = lease <- Keyword.get(opts, :credential_lease),
         {:ok, operation} <- Jido.Connect.action(Jido.Connect.MCP, "mcp.endpoint.ping") do
      requests =
        [{"mcp:notifications:listen", %{endpoint_id: endpoint}}] ++
          list_permissions(filter, endpoint) ++
          Enum.map(Map.get(filter, "resourceSubscriptions", []), fn uri ->
            {"mcp:resources:read", %{endpoint_id: endpoint, uri: uri}}
          end)

      Enum.reduce_while(requests, :ok, fn {scope, input}, :ok ->
        operation = Map.merge(operation, %{id: "mcp.notifications.listen", scopes: [scope]})

        case Authorization.authorize(operation, input, context, lease, opts) do
          :ok -> {:cont, :ok}
          error -> {:halt, error}
        end
      end)
    else
      _ -> {:error, Error.context_required()}
    end
  end

  defp list_permissions(filter, endpoint) do
    [
      {"toolsListChanged", "mcp:tools:list"},
      {"resourcesListChanged", "mcp:resources:list"},
      {"promptsListChanged", "mcp:prompts:list"}
    ]
    |> Enum.filter(fn {key, _scope} -> Map.get(filter, key) == true end)
    |> Enum.map(fn {_key, scope} -> {scope, %{endpoint_id: endpoint}} end)
  end

  defp open(%{legacy?: true}, _filter, _timeout),
    do:
      {:error,
       Error.config("Notification sessions require a managed endpoint lease",
         key: :credential_lease
       )}

  defp open(%{client_module: ExMCPClient} = token, filter, timeout) do
    with :ok <- dispatchable(token),
         {:ok, subscription} <- ExMCPClient.listen(token.client_ref, filter, timeout: timeout) do
      case dispatchable(token) do
        :ok ->
          {:ok, subscription}

        error ->
          ExMCPClient.close_subscription(subscription)
          error
      end
    end
  end

  defp open(_token, _filter, _timeout),
    do: {:error, Error.config("Notification sessions require ExMCP", key: :mcp_client_module)}

  defp dispatchable(%{legacy?: true}), do: :ok
  defp dispatchable(token), do: EndpointLeaseManager.ensure_dispatchable(token)
  defp release(%{legacy?: true}), do: :ok
  defp release(token), do: EndpointLeaseManager.release(token)
  defp same_subscription?(%{pid: pid}, %{pid: pid}), do: true
  defp same_subscription?(_, _), do: false
end
