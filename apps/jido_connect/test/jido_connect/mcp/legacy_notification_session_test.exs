defmodule Jido.Connect.MCP.LegacyNotificationSessionTest do
  use ExUnit.Case, async: false

  alias ExMCP.Server
  alias ExMCP.Server.HandlerServer
  alias Jido.Connect
  alias Jido.Connect.MCP.{EndpointLeaseManager, Session}

  defmodule Policy do
    def authorize(_, _, _, _), do: :ok
  end

  defmodule Handler do
    use ExMCP.Server.Handler

    @impl true
    def init(opts), do: {:ok, %{observer: Keyword.fetch!(opts, :observer)}}

    @impl true
    def handle_subscribe_resource(uri, state) do
      send(state.observer, {:server_subscribe, uri})
      {:ok, %{}, state}
    end

    @impl true
    def handle_unsubscribe_resource(uri, state) do
      send(state.observer, {:server_unsubscribe, uri})
      {:ok, %{}, state}
    end
  end

  defmodule ReconnectTransport do
    @behaviour ExMCP.Transport

    defstruct [:agent, :observer, :pending]

    @impl true
    def connect(opts) do
      agent = Keyword.fetch!(opts, :agent)
      observer = Keyword.fetch!(opts, :observer)

      attempt =
        Agent.get_and_update(agent, fn state ->
          attempt = state.connects + 1
          {attempt, %{state | connects: attempt}}
        end)

      send(observer, {:transport_connect, attempt})
      {:ok, %__MODULE__{agent: agent, observer: observer}}
    end

    @impl true
    def send_message(message, %__MODULE__{} = state) do
      case Jason.decode!(message) do
        %{"method" => "initialize", "id" => id} ->
          {:ok, %{state | pending: initialize_response(id)}}

        %{"method" => method, "id" => id, "params" => params}
        when method in ["resources/subscribe", "resources/unsubscribe"] ->
          send(state.observer, {:transport_request, method, params})

          response =
            if method == "resources/subscribe" and Agent.get(state.agent, & &1.fail_subscribe?),
              do: error_response(id),
              else: result_response(id)

          push(state, response)
          {:ok, state}

        _message ->
          {:ok, state}
      end
    end

    @impl true
    def receive_message(%__MODULE__{pending: nil}), do: {:error, :closed}

    def receive_message(%__MODULE__{pending: response} = state),
      do: {:ok, response, %{state | pending: nil}}

    @impl true
    def close(_state), do: :ok

    @impl true
    def connected?(_state), do: true

    @impl true
    def subscribe(client, %__MODULE__{} = state) do
      Agent.update(state.agent, &Map.put(&1, :client, client))
      {:ok, state}
    end

    @impl true
    def capabilities(_state), do: [:push]

    defp push(state, response) do
      client = Agent.get(state.agent, & &1.client)
      send(client, {:transport_message, response})
    end

    defp initialize_response(id) do
      Jason.encode!(%{
        "jsonrpc" => "2.0",
        "id" => id,
        "result" => %{
          "protocolVersion" => "2025-06-18",
          "capabilities" => %{"resources" => %{"subscribe" => true}},
          "serverInfo" => %{"name" => "legacy-reconnect", "version" => "1.0.0"}
        }
      })
    end

    defp result_response(id),
      do: Jason.encode!(%{"jsonrpc" => "2.0", "id" => id, "result" => %{}})

    defp error_response(id) do
      Jason.encode!(%{
        "jsonrpc" => "2.0",
        "id" => id,
        "error" => %{"code" => -32_602, "message" => "Resource unavailable"}
      })
    end
  end

  test "delivers authorized legacy events, sanitizes them, and releases resources" do
    %{client: client, server: server, opts: opts} = legacy_pair()

    assert {:ok, session} =
             Session.start_link(
               "test",
               %{
                 "toolsListChanged" => true,
                 "resourceSubscriptions" => ["test://document"]
               },
               opts
             )

    assert_receive {:server_subscribe, "test://document"}
    assert :ok = Server.notify_tools_changed(server)

    assert_receive {:jido_connect, :mcp, ^session, "notifications/tools/list_changed", %{}},
                   1_000

    assert :ok = Server.notify_resource_update(server, "test://private")
    assert :ok = Server.notify_resource_update(server, "test://document")

    assert_receive {:jido_connect, :mcp, ^session, "notifications/resources/updated",
                    %{"uri" => "test://document"}},
                   1_000

    refute_received {:jido_connect, :mcp, ^session, "notifications/resources/updated",
                     %{"uri" => "test://private"}}

    listener = :sys.get_state(session).subscription

    send(
      session,
      {:ex_mcp_notification, listener, "notifications/tools/list_changed",
       %{"access_token" => "secret-value", "name" => "public"}}
    )

    assert_receive {:jido_connect, :mcp, ^session, "notifications/tools/list_changed", params}
    refute inspect(params) =~ "secret-value"

    assert :ok = Session.close(session)
    assert_receive {:server_unsubscribe, "test://document"}, 1_000
    assert Process.alive?(client)
  end

  test "lease revocation closes a legacy session and cleans up its listener" do
    %{client: client, connection: connection, opts: opts} = legacy_pair()

    assert {:ok, session} =
             Session.start_link(
               "test",
               %{"resourceSubscriptions" => ["test://document"]},
               opts
             )

    assert_receive {:server_subscribe, "test://document"}
    monitor = Process.monitor(session)
    assert :ok = EndpointLeaseManager.force_stop(connection)
    assert_receive {:DOWN, ^monitor, :process, ^session, :normal}, 1_000
    assert_receive {:server_unsubscribe, "test://document"}, 1_000
    assert Process.alive?(client)
  end

  test "subscriber exit closes a legacy session and releases its resource" do
    %{client: client, opts: opts} = legacy_pair()

    owner =
      spawn(fn ->
        receive do
          :stop -> :ok
        end
      end)

    assert {:ok, session} =
             Session.start_link(
               "test",
               %{"resourceSubscriptions" => ["test://document"]},
               Keyword.put(opts, :subscriber, owner)
             )

    assert_receive {:server_subscribe, "test://document"}
    monitor = Process.monitor(session)
    send(owner, :stop)
    assert_receive {:DOWN, ^monitor, :process, ^session, :normal}, 1_000
    assert_receive {:server_unsubscribe, "test://document"}, 1_000
    assert Process.alive?(client)
  end

  test "rejects an unauthorized legacy resource before it creates a listener" do
    %{opts: opts} = legacy_pair()

    assert {:error, %Connect.Error.AuthError{reason: :missing_scopes}} =
             Session.start_link(
               "test",
               %{"resourceSubscriptions" => ["test://private"]},
               opts
             )

    refute_receive {:server_subscribe, "test://private"}, 100
  end

  test "keeps a legacy session active after ExMCP reconnects and re-subscribes" do
    {:ok, agent} =
      Agent.start_link(fn -> %{connects: 0, client: nil, fail_subscribe?: false} end)

    client =
      start_supervised!(
        {ExMCP.Client,
         transport: ReconnectTransport,
         agent: agent,
         observer: self(),
         protocol_mode: :legacy_only,
         health_check_interval: nil,
         reconnect_backoff: [initial: 10, max: 20, multiplier: 2]}
      )

    assert_receive {:transport_connect, 1}
    %{opts: opts} = session_context(client)

    assert {:ok, session} =
             Session.start_link(
               "test",
               %{"resourceSubscriptions" => ["test://document"]},
               opts
             )

    assert_receive {:transport_request, "resources/subscribe", %{"uri" => "test://document"}}

    send(client, {:transport_closed, :connection_lost})
    assert_receive {:transport_connect, 2}, 1_000

    assert_receive {:transport_request, "resources/subscribe", %{"uri" => "test://document"}},
                   1_000

    assert_receive {:jido_connect, :mcp, ^session, :status, :active}, 1_000
    assert %{status: :active} = Session.status(session)
  end

  test "closes a legacy session when a requested resource cannot be restored" do
    {:ok, agent} =
      Agent.start_link(fn -> %{connects: 0, client: nil, fail_subscribe?: false} end)

    client =
      start_supervised!(
        {ExMCP.Client,
         transport: ReconnectTransport,
         agent: agent,
         observer: self(),
         protocol_mode: :legacy_only,
         health_check_interval: nil,
         reconnect_backoff: [initial: 10, max: 20, multiplier: 2]}
      )

    assert_receive {:transport_connect, 1}
    %{opts: opts} = session_context(client)

    assert {:ok, session} =
             Session.start_link(
               "test",
               %{"resourceSubscriptions" => ["test://document"]},
               opts
             )

    assert_receive {:transport_request, "resources/subscribe", %{"uri" => "test://document"}}
    Agent.update(agent, &Map.put(&1, :fail_subscribe?, true))
    monitor = Process.monitor(session)

    send(client, {:transport_closed, :connection_lost})
    assert_receive {:transport_connect, 2}, 1_000

    assert_receive {:transport_request, "resources/subscribe", %{"uri" => "test://document"}},
                   1_000

    assert_receive {:jido_connect, :mcp, ^session, :status, :failed}, 1_000
    assert_receive {:DOWN, ^monitor, :process, ^session, :normal}, 1_000
  end

  defp legacy_pair do
    server =
      start_supervised!(
        {HandlerServer,
         handler: Handler,
         handler_args: [observer: self()],
         transport: :test,
         protocol_mode: :legacy_only}
      )

    client =
      start_supervised!(
        {ExMCP.Client,
         transport: :test, server: server, protocol_mode: :legacy_only, health_check_interval: nil},
        id: make_ref()
      )

    session_context(client) |> Map.put(:server, server)
  end

  defp session_context(client) do
    id = "legacy-notifications-#{System.unique_integer([:positive])}"

    connection =
      Connect.Connection.new!(%{
        id: id,
        provider: :mcp,
        profile: :endpoint,
        tenant_id: "tenant",
        owner_type: :tenant,
        owner_id: "tenant",
        status: :connected,
        metadata: %{mcp_endpoint_id: "test", connection_revision: 1},
        scopes: [
          "mcp:endpoint:test",
          "mcp:notifications:listen",
          "mcp:resources:read",
          "mcp:resource:test://document",
          "mcp:tools:list"
        ]
      })

    context =
      Connect.Context.new!(%{
        tenant_id: "tenant",
        actor: %{id: "user", type: :user},
        connection: connection
      })

    lease =
      Connect.CredentialLease.from_connection!(connection, %{mcp_client_ref: client},
        expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
        metadata: %{credential_version: 1}
      )

    on_exit(fn -> EndpointLeaseManager.force_stop(connection) end)

    %{
      client: client,
      connection: connection,
      opts: [context: context, credential_lease: lease, policy: Policy]
    }
  end
end
