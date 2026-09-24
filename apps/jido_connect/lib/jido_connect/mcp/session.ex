defmodule Jido.Connect.MCP.Session do
  @moduledoc """
  Host-owned notification session for an authorized MCP endpoint.

  Start this process under the host supervisor. Pass the same `:context`,
  `:credential_lease`, and `:policy` options used for Connect operations.
  `:subscriber` defaults to the caller. Events arrive as
  `{:jido_connect, :mcp, session, method, sanitized_params}`.

  The immutable filter supports toolsListChanged, resourcesListChanged,
  promptsListChanged, and resourceSubscriptions. Each selected capability is
  authorized before the session opens. Modern streams use MCP 2026-07-28;
  legacy peers use ExMCP's local notification listener. ExMCP owns
  acknowledgment, reconnect, and protocol state. The session keeps the
  authorized filter and checks it before it forwards events or resync data.
  It also checks the endpoint lease before each event and stops when the lease is retired.
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
          if subscription_filter_authorized?(subscription, filter) do
            Process.send_after(self(), :check_lease, 100)

            {:ok,
             %{
               endpoint_id: endpoint_id,
               status: :active,
               token: token,
               filter: filter,
               subscription: subscription,
               owner: owner,
               monitor: Process.monitor(owner),
               subscription_monitor: Process.monitor(subscription_monitor_target(subscription))
             }}
          else
            ExMCPClient.close_subscription(subscription)
            release(token)

            {:stop,
             Error.auth("MCP subscription exceeds the authorized filter",
               reason: :mcp_filter_expanded
             )}
          end

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
    {:reply, %{endpoint_id: state.endpoint_id, status: state.status}, state}
  end

  @impl true
  def handle_info({:ex_mcp_subscription, subscription, method, params}, state) do
    if same_subscription?(subscription, state.subscription) do
      case dispatchable_subscription(state, subscription) do
        :ok ->
          if event_authorized?(method, params, state.filter) do
            send(state.owner, {:jido_connect, :mcp, self(), method, Sanitizer.sanitize(params)})
          end

          {:noreply, state}

        {:error, _} ->
          {:stop, :normal, state}
      end
    else
      {:noreply, state}
    end
  end

  def handle_info({:ex_mcp_notification, listener, method, params}, state) do
    if same_subscription?(listener, state.subscription) do
      case dispatchable_subscription(state, listener) do
        :ok ->
          if event_authorized?(method, params, state.filter) do
            send(state.owner, {:jido_connect, :mcp, self(), method, Sanitizer.sanitize(params)})
          end

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
      case dispatchable_subscription(state, subscription) do
        :ok ->
          send(
            state.owner,
            {:jido_connect, :mcp, self(), :resync, Sanitizer.sanitize(public_snapshot(snapshot))}
          )

          {:noreply, %{state | status: :active}}

        {:error, _} ->
          {:stop, :normal, state}
      end
    else
      {:noreply, state}
    end
  end

  def handle_info({:ex_mcp_subscription_resync, subscription, phase}, state) do
    if same_subscription?(subscription, state.subscription) do
      case {dispatchable(state.token), phase} do
        {:ok, :started} ->
          send(state.owner, {:jido_connect, :mcp, self(), :status, :reconnecting})
          {:noreply, %{state | status: :reconnecting}}

        {:ok, {:failed, _reason}} ->
          send(state.owner, {:jido_connect, :mcp, self(), :status, :failed})
          {:stop, :normal, state}

        {{:error, _}, _} ->
          {:stop, :normal, state}

        _ ->
          {:noreply, state}
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

  def handle_info({:ex_mcp_notification_reconnected, listener, result}, state) do
    if same_subscription?(listener, state.subscription) do
      case {dispatchable_subscription(state, listener), result} do
        {:ok, %{failed: []}} ->
          send(state.owner, {:jido_connect, :mcp, self(), :status, :active})
          {:noreply, %{state | status: :active}}

        {:ok, %{failed: failed}} when is_list(failed) ->
          send(state.owner, {:jido_connect, :mcp, self(), :status, :failed})
          {:stop, :normal, state}

        {{:error, _}, _} ->
          {:stop, :normal, state}

        _ ->
          send(state.owner, {:jido_connect, :mcp, self(), :status, :failed})
          {:stop, :normal, state}
      end
    else
      {:noreply, state}
    end
  end

  def handle_info({:ex_mcp_notification_closed, listener, _reason}, state) do
    if same_subscription?(listener, state.subscription),
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
         {:ok, subscription} <-
           ExMCPClient.open_notifications(token.client_ref, filter, timeout: timeout) do
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

  defp dispatchable_subscription(state, subscription) do
    if subscription_filter_authorized?(subscription, state.filter) do
      dispatchable(state.token)
    else
      {:error, :mcp_filter_expanded}
    end
  end

  defp subscription_filter_authorized?(%{acknowledged_filter: acknowledged}, requested)
       when is_map(acknowledged) do
    filter_authorized?(acknowledged, requested)
  end

  defp subscription_filter_authorized?(
         %ExMCP.Client.NotificationListener.Ref{filter: filter},
         requested
       )
       when is_map(filter) do
    filter_authorized?(filter, requested)
  end

  defp subscription_filter_authorized?(_subscription, _requested), do: false

  defp filter_authorized?(acknowledged, requested) do
    Enum.all?(acknowledged, fn
      {"resourceSubscriptions", uris} when is_list(uris) ->
        requested_uris = Map.get(requested, "resourceSubscriptions", [])
        Enum.all?(uris, &(&1 in requested_uris))

      {key, true} when key in @keys ->
        Map.get(requested, key) == true

      {key, false} when key in @keys ->
        true

      _other ->
        false
    end)
  end

  defp event_authorized?("notifications/tools/list_changed", _params, filter),
    do: Map.get(filter, "toolsListChanged") == true

  defp event_authorized?("notifications/resources/list_changed", _params, filter),
    do: Map.get(filter, "resourcesListChanged") == true

  defp event_authorized?("notifications/prompts/list_changed", _params, filter),
    do: Map.get(filter, "promptsListChanged") == true

  defp event_authorized?("notifications/resources/updated", %{"uri" => uri}, filter),
    do: uri in Map.get(filter, "resourceSubscriptions", [])

  defp event_authorized?(_method, _params, _filter), do: false

  defp release(%{legacy?: true}), do: :ok
  defp release(token), do: EndpointLeaseManager.release(token)
  defp public_snapshot({:error, _reason}), do: {:error, :request_failed}
  defp public_snapshot({:ok, result}), do: {:ok, public_snapshot(result)}

  defp public_snapshot(value) when is_map(value),
    do: Map.new(value, fn {key, item} -> {key, public_snapshot(item)} end)

  defp public_snapshot(value) when is_list(value), do: Enum.map(value, &public_snapshot/1)
  defp public_snapshot(value), do: value

  defp same_subscription?(pid, %{pid: pid}) when is_pid(pid), do: true
  defp same_subscription?(%{pid: pid}, %{pid: pid}), do: true

  defp same_subscription?(
         %ExMCP.Client.NotificationListener.Ref{id: id, client: client},
         %ExMCP.Client.NotificationListener.Ref{id: id, client: client}
       ),
       do: true

  defp same_subscription?(_, _), do: false

  defp subscription_monitor_target(%ExMCP.Client.NotificationListener.Ref{client: client}),
    do: client

  defp subscription_monitor_target(%{pid: pid}), do: pid
end
