defmodule Jido.Connect.MCP.ClientCapabilitiesTest do
  use ExUnit.Case, async: false
  alias Jido.Connect
  alias Jido.Connect.MCP.{EndpointLeaseManager, ExMCPClient, Session}

  defmodule Policy do
    def authorize(_, _, _, _), do: :ok
  end

  defmodule Server do
    use ExMCP.Server.Handler
    use ExMCP.Server.DSL, name: "capabilities", version: "1.0.0"

    @impl true
    def handle_complete(_ref, _argument, state),
      do: {:ok, %{values: ["review"], total: 1, hasMore: false}, state}

    resource "test://document", "Document" do
      mime_type("text/plain")
      read(fn _, state -> {:ok, "document content", state} end)
    end

    resource_template "test://documents/{id}", "Documents" do
      param(:id, :string)
      read(fn %{id: id}, state -> {:ok, id, state} end)
    end

    prompt "review", "Review" do
      arg(:text, required: true)

      render(fn %{text: text}, state ->
        {:ok, %{messages: [%{role: "user", content: %{type: "text", text: text}}]}, state}
      end)
    end
  end

  defmodule PagedClient do
    def list_tools(owner, opts) do
      send(owner, {:page, Keyword.get(opts, :cursor)})

      case Keyword.get(opts, :cursor) do
        nil ->
          {:ok, %{"tools" => [], "nextCursor" => "second"}}

        "second" ->
          {:ok, %{"tools" => [%{"name" => "read", "inputSchema" => %{"type" => "object"}}]}}
      end
    end

    def call_tool(owner, "read", _, _) do
      send(owner, :tool_called)
      {:ok, %{"content" => [%{"type" => "text", "text" => "done"}]}}
    end

    def list_resources(_, _), do: {:ok, %{"resources" => "invalid"}}
  end

  setup do
    registry = start_supervised!({ExMCP.Server.Subscriptions, name: nil})

    server =
      start_supervised!(
        {ExMCP.Server.HandlerServer,
         handler: Server,
         transport: :test,
         protocol_mode: :modern_only,
         subscription_registry: registry}
      )

    client =
      start_supervised!(
        {ExMCP.Client,
         transport: :test, server: server, protocol_mode: :modern_only, health_check_interval: nil}
      )

    id = "capabilities-#{System.unique_integer([:positive])}"

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
          "mcp:resources:list",
          "mcp:resources:read",
          "mcp:resource:test://document",
          "mcp:prompts:list",
          "mcp:prompts:get",
          "mcp:prompt:review",
          "mcp:completion:complete",
          "mcp:endpoint:inspect",
          "mcp:notifications:listen",
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
      server: server,
      context: context,
      lease: lease,
      opts: [context: context, credential_lease: lease, policy: Policy]
    }
  end

  test "reads resources, templates, and prompts through generated actions", state do
    assert {:ok, %{result: %{"resources" => [resource]}}} = run(:ListResources, %{}, state)
    assert resource["uri"] == "test://document"

    assert {:ok, %{result: %{"resourceTemplates" => [template]}}} =
             run(:ListResourceTemplates, %{}, state)

    assert template["uriTemplate"] == "test://documents/{id}"

    assert {:ok, %{result: %{"contents" => [%{"text" => "document content"}]}}} =
             run(:ReadResource, %{uri: "test://document"}, state)

    assert {:ok, %{result: %{"prompts" => [prompt]}}} = run(:ListPrompts, %{}, state)
    assert prompt["name"] == "review"

    assert {:ok, %{result: %{"messages" => [%{"content" => %{"text" => "review me"}}]}}} =
             run(:GetPrompt, %{prompt_name: "review", arguments: %{"text" => "review me"}}, state)

    assert {:ok, %{result: %{"values" => ["review"]}}} =
             run(
               :Complete,
               %{
                 ref: %{"type" => "ref/prompt", "name" => "review"},
                 argument: %{"name" => "text", "value" => "r"}
               },
               state
             )

    assert {:ok, %{result: %{}}} = run(:Ping, %{}, state)
    assert {:ok, %{result: status}} = run(:Status, %{}, state)
    assert status["protocol_version"]
    refute Map.has_key?(status, "transport")
  end

  test "generated status action applies its timeout and keeps public fields", state do
    assert {:ok, %{result: status}} = run(:Status, %{timeout: 1_000}, state)
    assert status["protocol_version"]
    refute Map.has_key?(status, "transport")

    assert {:error, %{reason: :invalid_params}} =
             ExMCPClient.status(state.client, timeout: 0)

    :ok = :sys.suspend(state.client)

    try do
      started_at = System.monotonic_time(:millisecond)

      assert {:error, %Connect.Error.ProviderError{reason: :timeout}} =
               run(:Status, %{timeout: 20}, state)

      assert System.monotonic_time(:millisecond) - started_at < 1_000
    after
      :ok = :sys.resume(state.client)
    end
  end

  test "requires resource and prompt permission before dispatch", state do
    assert {:error, %Connect.Error.AuthError{reason: :missing_scopes}} =
             run(:ReadResource, %{uri: "test://private"}, state)

    assert {:error, %Connect.Error.AuthError{reason: :missing_scopes}} =
             run(:GetPrompt, %{prompt_name: "private"}, state)

    assert {:error, %Connect.Error.AuthError{reason: :missing_scopes}} =
             run(
               :Complete,
               %{
                 ref: %{"type" => "ref/prompt", "name" => "private"},
                 argument: %{"name" => "text", "value" => "x"}
               },
               state
             )

    assert {:error, _} =
             run(
               :Complete,
               %{ref: %{"type" => "unknown"}, argument: %{"name" => "text", "value" => "x"}},
               state
             )
  end

  test "routes notifications and releases a session without stopping its host client", state do
    assert {:ok, session} =
             Session.start_link(
               "test",
               %{"resourceSubscriptions" => ["test://document"]},
               state.opts
             )

    assert %{endpoint_id: "test", status: :active} = Session.status(session)
    assert :ok = ExMCP.Server.notify_resource_update(state.server, "test://document")

    assert_receive {:jido_connect_mcp, ^session, "notifications/resources/updated",
                    %{"uri" => "test://document"}},
                   1_000

    assert :ok = Session.close(session)
    assert Process.alive?(state.client)
  end

  test "connection revocation stops the notification session", state do
    assert {:ok, session} = Session.start_link("test", %{"toolsListChanged" => true}, state.opts)
    ref = Process.monitor(session)
    assert :ok = EndpointLeaseManager.force_stop(state.context.connection)
    assert_receive {:DOWN, ^ref, :process, ^session, :normal}, 1_000
    assert Process.alive?(state.client)
  end

  test "invalid subscription filters and unauthorized resources are rejected", state do
    assert {:error, _} =
             Session.start_link("test", %{"resourceSubscriptions" => true}, state.opts)

    assert {:error, _} =
             Session.start_link(
               "test",
               %{"resourceSubscriptions" => ["test://private"]},
               state.opts
             )

    assert {:error, _} = ExMCPClient.list_resources(state.client, cursor: 1)
  end

  test "subscriber death closes its session", state do
    owner =
      spawn(fn ->
        receive do
          :stop -> :ok
        end
      end)

    {:ok, session} =
      Session.start_link(
        "test",
        %{"toolsListChanged" => true},
        Keyword.put(state.opts, :subscriber, owner)
      )

    ref = Process.monitor(session)
    send(owner, :stop)
    assert_receive {:DOWN, ^ref, :process, ^session, :normal}, 1_000
    assert Process.alive?(state.client)
  end

  test "subscription closure also closes the session", state do
    {:ok, session} = Session.start_link("test", %{"toolsListChanged" => true}, state.opts)
    ref = Process.monitor(session)
    subscription = :sys.get_state(session).subscription
    ExMCPClient.close_subscription(subscription)
    assert_receive {:DOWN, ^ref, :process, ^session, :normal}, 1_000
  end

  test "public events redact secret fields and ignore other subscriptions", state do
    {:ok, session} = Session.start_link("test", %{"toolsListChanged" => true}, state.opts)
    subscription = :sys.get_state(session).subscription
    send(session, {:ex_mcp_subscription_resync, subscription.pid, :started})
    assert_receive {:jido_connect_mcp, ^session, :status, :reconnecting}
    assert %{status: :reconnecting} = Session.status(session)
    send(session, {:ex_mcp_subscription, %{pid: self()}, "ignored", %{}})
    refute_receive {:jido_connect_mcp, ^session, "ignored", _}

    send(
      session,
      {:ex_mcp_subscription, subscription, "notifications/tools/list_changed",
       %{"access_token" => "secret-value", "name" => "public"}}
    )

    assert_receive {:jido_connect_mcp, ^session, _, params}
    refute inspect(params) =~ "secret-value"

    send(
      session,
      {:ex_mcp_subscription_resync, subscription,
       {:complete, %{"access_token" => "secret-value", "resources" => {:error, "secret-value"}}}}
    )

    assert_receive {:jido_connect_mcp, ^session, :resync, snapshot}
    refute inspect(snapshot) =~ "secret-value"
    assert %{status: :active} = Session.status(session)
    monitor = Process.monitor(session)
    send(session, {:ex_mcp_subscription_resync, subscription.pid, {:failed, "secret-value"}})
    assert_receive {:jido_connect_mcp, ^session, :status, :failed}
    assert_receive {:DOWN, ^monitor, :process, ^session, :normal}
  end

  test "session rejects events and resync data outside its authorized filter", state do
    {:ok, session} = Session.start_link("test", %{"toolsListChanged" => true}, state.opts)
    subscription = :sys.get_state(session).subscription

    send(
      session,
      {:ex_mcp_subscription, subscription, "notifications/resources/updated",
       %{"uri" => "test://private"}}
    )

    refute_receive {:jido_connect_mcp, ^session, "notifications/resources/updated", _}, 100

    broadened = %{
      subscription
      | acknowledged_filter:
          Map.put(subscription.acknowledged_filter, "resourceSubscriptions", ["test://private"])
    }

    monitor = Process.monitor(session)

    send(
      session,
      {:ex_mcp_subscription_resync, broadened,
       {:complete, %{"resources" => %{"test://private" => {:ok, "private"}}}}}
    )

    assert_receive {:DOWN, ^monitor, :process, ^session, :normal}, 1_000
    refute_receive {:jido_connect_mcp, ^session, :resync, _}
    assert Process.alive?(state.client)
  end

  test "schema validation finds tools on later pages and rejects malformed lists", state do
    lease =
      Connect.CredentialLease.from_connection!(
        state.context.connection,
        %{mcp_client_module: PagedClient, mcp_client_ref: self()},
        expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
        metadata: %{credential_version: 1}
      )

    opts = [context: state.context, credential_lease: lease]

    assert {:ok, _} =
             Jido.Connect.MCP.Runtime.call_typed_tool(
               %{
                 endpoint_id: "test",
                 tool_name: "read",
                 arguments: %{},
                 expected_schema_hash: Jido.Connect.MCP.Tool.schema_hash(%{"type" => "object"})
               },
               opts,
               mutation?: false
             )

    assert_receive {:page, nil}
    assert_receive {:page, "second"}
    assert_receive :tool_called

    assert {:error, %Connect.Error.ProviderError{reason: :invalid_response}} =
             Jido.Connect.MCP.Runtime.read_operation(
               :list_resources,
               %{endpoint_id: "test"},
               opts
             )
  end

  defp run(name, input, state) do
    module = Module.concat(Jido.Connect.MCP.Actions, name)

    module.run(
      Map.put(input, :endpoint_id, "test"),
      %{integration_context: state.context, credential_lease: state.lease, policy: Policy}
    )
  end
end
