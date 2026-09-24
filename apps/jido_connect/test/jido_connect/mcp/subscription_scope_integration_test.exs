defmodule Jido.Connect.MCP.SubscriptionScopeIntegrationTest do
  use ExUnit.Case, async: false

  alias Jido.Connect
  alias Jido.Connect.MCP.{EndpointLeaseManager, Session}

  defmodule Policy do
    def authorize(_, _, _, _), do: :ok
  end

  defmodule AckClient do
    use GenServer

    def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

    @impl true
    def init(opts) do
      {:ok,
       %{
         observer: Keyword.fetch!(opts, :observer),
         acknowledgments: opts[:acknowledgments],
         next_id: 1
       }}
    end

    @impl true
    def handle_call({:register_notification_listener, _filter, _subscriber}, _from, state) do
      {:reply, {:error, :use_listen}, state}
    end

    def handle_call({:open_subscription, subscription, requested}, _from, state) do
      id = state.next_id
      acknowledged = Enum.at(state.acknowledgments, id - 1, requested)
      send(state.observer, {:subscription_opened, id})

      send(subscription, {
        :client_subscription_acknowledged,
        id,
        %{
          "_meta" => %{"io.modelcontextprotocol/subscriptionId" => id},
          "notifications" => acknowledged
        }
      })

      {:reply, {:ok, id}, %{state | next_id: id + 1}}
    end

    def handle_call({:request, "resources/read", %{"uri" => uri}, _opts}, _from, state) do
      send(state.observer, {:resource_read, uri})
      {:reply, {:error, :not_found}, state}
    end

    @impl true
    def handle_cast({:close_subscription, _subscription, id, _reason}, state) do
      send(state.observer, {:subscription_closed, id})
      {:noreply, state}
    end
  end

  setup do
    connection =
      Connect.Connection.new!(%{
        id: "subscription-scope-#{System.unique_integer([:positive])}",
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

    on_exit(fn -> EndpointLeaseManager.force_stop(connection) end)
    %{connection: connection, context: context}
  end

  test "expanded initial acknowledgment cannot activate a session", state do
    requested = %{"resourceSubscriptions" => ["test://document"]}
    expanded = %{"resourceSubscriptions" => ["test://document", "test://private"]}
    opts = session_opts(state, [expanded])

    result =
      Task.async(fn ->
        Process.flag(:trap_exit, true)
        Session.start_link("test", requested, opts)
      end)
      |> Task.await()

    assert {:error, %Connect.Error.ProviderError{reason: :subscription_failed}} = result

    assert_receive {:subscription_opened, 1}
    assert_receive {:subscription_closed, 1}
    refute_receive {:resource_read, _uri}, 100
    refute_receive {:jido_connect, :mcp, _session, :resync, _snapshot}
  end

  test "equal and narrower acknowledgments remain usable", state do
    requested = %{
      "toolsListChanged" => true,
      "resourceSubscriptions" => ["test://document"]
    }

    for acknowledged <- [requested, %{"resourceSubscriptions" => ["test://document"]}] do
      opts = session_opts(state, [acknowledged])
      assert {:ok, session} = Session.start_link("test", requested, opts)
      assert %{status: :active} = Session.status(session)
      subscription = :sys.get_state(session).subscription
      assert subscription.acknowledged_filter == acknowledged

      send(subscription.pid, {
        :client_subscription_event,
        subscription.request_id,
        "notifications/resources/updated",
        %{"uri" => "test://document"}
      })

      assert_receive {:jido_connect, :mcp, ^session, "notifications/resources/updated",
                      %{"uri" => "test://document"}}

      assert :ok = Session.close(session)
    end
  end

  test "expanded reconnect acknowledgment causes no private read or snapshot", state do
    requested = %{"resourceSubscriptions" => ["test://document"]}
    expanded = %{"resourceSubscriptions" => ["test://document", "test://private"]}
    opts = session_opts(state, [requested, expanded])

    assert {:ok, session} = Session.start_link("test", requested, opts)
    subscription = :sys.get_state(session).subscription
    monitor = Process.monitor(session)

    send(subscription.pid, {:client_subscription_disconnected, :transport_closed})
    assert_receive {:jido_connect, :mcp, ^session, :status, :reconnecting}
    send(subscription.pid, :client_subscription_reconnect)
    assert_receive {:subscription_opened, 2}
    assert_receive {:jido_connect, :mcp, ^session, :status, :failed}
    assert_receive {:DOWN, ^monitor, :process, ^session, :normal}
    assert_receive {:subscription_closed, 2}
    refute_receive {:resource_read, _uri}, 100
    refute_receive {:jido_connect, :mcp, ^session, :resync, _snapshot}
  end

  defp session_opts(state, acknowledgments) do
    client =
      start_supervised!(
        {AckClient, observer: self(), acknowledgments: acknowledgments},
        id: make_ref()
      )

    lease =
      Connect.CredentialLease.from_connection!(
        state.connection,
        %{mcp_client_ref: client},
        expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
        metadata: %{credential_version: 1}
      )

    [context: state.context, credential_lease: lease, policy: Policy]
  end
end
