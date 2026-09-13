defmodule Jido.Connect.MCPTest do
  use ExUnit.Case

  alias Jido.Connect

  defmodule AllowPolicy do
    def authorize(_operation, _input, _context, _connection), do: :ok
  end

  defmodule FakeMCPClient do
    @behaviour Jido.Connect.MCP.Client

    def list_tools(:filesystem, []) do
      {:ok,
       %{
         "tools" => [
           %{
             name: "read_text_file",
             description: "Read a text file without a timeout",
             inputSchema: %{"type" => "object"}
           }
         ]
       }}
    end

    def list_tools(:filesystem, opts) do
      assert opts[:timeout] == 1_000

      {:ok,
       %{
         "tools" => [
           %{
             "name" => "read_text_file",
             "description" => "Read a text file",
             "inputSchema" => %{"type" => "object"},
             "annotations" => %{"readOnlyHint" => true}
           }
         ]
       }}
    end

    def call_tool(:filesystem, "read_text_file", %{"path" => "/tmp/readme.md"}, opts) do
      assert opts[:timeout] == 1_000

      {:ok,
       %{
         "content" => [%{"type" => "text", "text" => "hello"}]
       }}
    end

    def call_tool(:filesystem, "fail", %{}, opts) do
      assert opts[:timeout] == 1_000
      {:error, %{reason: :transport}}
    end
  end

  defmodule BadMCPClient do
    @behaviour Jido.Connect.MCP.Client

    def list_tools(:filesystem, _opts), do: :bad_response
    def call_tool(_client, _name, _arguments, _opts), do: {:ok, %{}}
  end

  defmodule RaisingMCPClient do
    @behaviour Jido.Connect.MCP.Client

    def list_tools(:filesystem, _opts), do: raise("mcp exploded")
    def call_tool(_client, _name, _arguments, _opts), do: {:ok, %{}}
  end

  defmodule HostMCPClient do
    @behaviour Jido.Connect.MCP.Client

    def list_tools(client_ref, opts) do
      send(self(), {:host_mcp_discovered, client_ref, opts})

      {:ok,
       %{
         "tools" => [
           %{
             "name" => "post_message",
             "inputSchema" => %{
               "type" => "object",
               "properties" => %{"text" => %{"type" => "string"}}
             }
           }
         ]
       }}
    end

    def call_tool(client_ref, "post_message", %{"text" => text}, opts) do
      send(self(), {:host_mcp_called, client_ref, text, opts})

      {:ok,
       %{
         "content" => [%{"type" => "text", "text" => "sent"}]
       }}
    end
  end

  defmodule UnknownOutcomeClient do
    @behaviour Jido.Connect.MCP.Client

    def list_tools(_client_ref, _opts), do: {:ok, %{"tools" => []}}

    def call_tool(observer, "write", %{}, opts) do
      send(observer, {:unknown_outcome_attempt, opts})
      {:error, %{reason: :outcome_unknown, details: %{delivery: :unknown}}}
    end
  end

  setup do
    previous = Application.get_env(:jido_connect, :mcp_clients)
    register_client!(:filesystem, FakeMCPClient)

    on_exit(fn ->
      if is_nil(previous),
        do: Application.delete_env(:jido_connect, :mcp_clients),
        else: Application.put_env(:jido_connect, :mcp_clients, previous)
    end)

    :ok
  end

  test "MCP integration declares bridge actions" do
    spec = Jido.Connect.MCP.integration()

    assert spec.id == :mcp
    assert spec.package == :jido_connect
    assert spec.status == :experimental
    assert spec.metadata.bridge?
    assert [%{id: :endpoint_access}] = spec.policies
    assert {:endpoint, :api_key} in Enum.map(spec.auth_profiles, &{&1.id, &1.kind})

    assert {:ok,
            %{
              id: "mcp.tools.list",
              resource: :mcp_tool,
              verb: :list,
              policies: [:endpoint_access],
              mutation?: false,
              scope_resolver: Jido.Connect.MCP.ScopeResolver
            }} = Connect.action(spec, "mcp.tools.list")

    assert {:ok,
            %{
              id: "mcp.tool.call",
              mutation?: true,
              confirmation: :required_for_ai,
              scope_resolver: Jido.Connect.MCP.ScopeResolver
            }} = Connect.action(spec, "mcp.tool.call")
  end

  test "MCP catalog entry exposes bridge and runtime capabilities" do
    entry = Connect.Catalog.entry(Jido.Connect.MCP)
    features = entry.capabilities |> Enum.map(& &1.feature) |> MapSet.new()

    assert entry.package == :jido_connect
    assert entry.status == :experimental
    assert MapSet.member?(features, :api_key)
    assert MapSet.member?(features, :generated_jido_actions)
    assert MapSet.member?(features, :mcp_bridge)
  end

  test "MCP integration compiles generated Jido modules" do
    assert Application.get_env(:jido_connect, :jido_connect_providers) == [
             Jido.Connect.MCP
           ]

    assert Jido.Connect.MCP.jido_action_modules() == [
             Jido.Connect.MCP.Actions.ListTools,
             Jido.Connect.MCP.Actions.CallTool
           ]

    assert Jido.Connect.MCP.jido_sensor_modules() == []
    assert Jido.Connect.MCP.jido_plugin_module() == Jido.Connect.MCP.Plugin

    assert %Connect.Catalog.Manifest{
             id: :mcp,
             package: :jido_connect,
             generated_modules: %{
               actions: [
                 Jido.Connect.MCP.Actions.ListTools,
                 Jido.Connect.MCP.Actions.CallTool
               ],
               sensors: [],
               plugin: Jido.Connect.MCP.Plugin
             }
           } = Jido.Connect.MCP.jido_connect_manifest()

    assert {:module, Jido.Connect.MCP.Actions.ListTools} =
             Code.ensure_loaded(Jido.Connect.MCP.Actions.ListTools)

    assert {:module, Jido.Connect.MCP.Plugin} = Code.ensure_loaded(Jido.Connect.MCP.Plugin)
    assert function_exported?(Jido.Connect.MCP.Actions.ListTools, :run, 2)
    assert function_exported?(Jido.Connect.MCP.Plugin, :plugin_spec, 1)
  end

  test "generated list tools action delegates through the client contract" do
    {context, lease} = context_and_lease()

    assert {:ok, %{endpoint_id: "filesystem", tools: [tool]}} =
             Jido.Connect.MCP.Actions.ListTools.run(
               %{endpoint_id: "filesystem", timeout: 1_000},
               action_context(context, lease)
             )

    assert tool.name == "read_text_file"
    assert tool.description == "Read a text file"
    assert tool.input_schema == %{"type" => "object"}
    assert tool.schema_hash == Jido.Connect.MCP.Tool.schema_hash(tool.input_schema)
  end

  test "list tools supports clients without explicit timeout opts" do
    {context, lease} = context_and_lease()

    assert {:ok, %{tools: [tool]}} =
             Jido.Connect.MCP.Actions.ListTools.run(
               %{endpoint_id: "filesystem"},
               action_context(context, lease)
             )

    assert tool.description == "Read a text file without a timeout"
  end

  test "generated call tool action delegates through the client contract" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              result: %{
                endpoint_id: "filesystem",
                tool_name: "read_text_file",
                content: [%{"text" => "hello"}],
                is_error?: false
              }
            }} =
             Jido.Connect.MCP.Actions.CallTool.run(
               %{
                 endpoint_id: "filesystem",
                 tool_name: "read_text_file",
                 arguments: %{"path" => "/tmp/readme.md"},
                 timeout: 1_000
               },
               action_context(context, lease)
             )
  end

  test "MCP client errors normalize to provider errors" do
    {context, lease} =
      context_and_lease(
        scopes: [
          "mcp:tools:call",
          "mcp:endpoint:filesystem",
          "mcp:tool:fail"
        ]
      )

    assert {:error,
            %Connect.Error.ProviderError{
              provider: :mcp,
              reason: :transport,
              message: "MCP request failed"
            }} =
             Jido.Connect.MCP.Actions.CallTool.run(
               %{
                 endpoint_id: "filesystem",
                 tool_name: "fail",
                 arguments: %{},
                 timeout: 1_000
               },
               action_context(context, lease)
             )
  end

  test "an ExMCP unknown outcome becomes one uncertain write" do
    scopes = ["mcp:tools:call", "mcp:endpoint:remote", "mcp:tool:write"]

    connection =
      Connect.Connection.new!(%{
        id: "unknown-outcome",
        provider: :mcp,
        profile: :endpoint,
        tenant_id: "tenant_1",
        owner_type: :tenant,
        owner_id: "tenant_1",
        status: :connected,
        scopes: scopes,
        metadata: %{mcp_endpoint_id: "remote", connection_revision: 1}
      })

    context =
      Connect.Context.new!(%{
        tenant_id: "tenant_1",
        actor: %{id: "user_1", type: :user},
        connection: connection
      })

    lease =
      Connect.CredentialLease.from_connection!(
        connection,
        %{mcp_client_module: UnknownOutcomeClient, mcp_client_ref: self()},
        expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
        metadata: %{credential_version: 1}
      )

    assert {:error,
            %Connect.Error.ProviderError{
              reason: :mcp_write_uncertain,
              delivery: :sent_outcome_unknown,
              mutation?: true
            }} =
             Jido.Connect.MCP.Actions.CallTool.run(
               %{endpoint_id: "remote", tool_name: "write", arguments: %{}, timeout: 1_000},
               action_context(context, lease)
             )

    assert_received {:unknown_outcome_attempt, [timeout: 1_000]}
    refute_received {:unknown_outcome_attempt, _opts}
    assert :ok = Jido.Connect.MCP.EndpointLeaseManager.force_stop(connection)
  end

  test "typed read calls retain lease fences without mutation uncertainty" do
    {context, lease} =
      context_and_lease(
        scopes: [
          "mcp:tools:call",
          "mcp:endpoint:filesystem",
          "mcp:tool:fail"
        ]
      )

    assert {:error,
            %Connect.Error.ProviderError{
              provider: :mcp,
              reason: :transport,
              mutation?: false
            }} =
             Jido.Connect.MCP.Runtime.call_typed_tool(
               %{
                 endpoint_id: "filesystem",
                 tool_name: "fail",
                 arguments: %{},
                 expected_schema_hash: nil,
                 timeout: 1_000
               },
               %{
                 context: context,
                 credential_lease: lease,
                 credentials: lease.fields
               },
               mutation?: false
             )
  end

  test "MCP invalid client responses normalize to provider errors" do
    {context, lease} = context_and_lease(mcp_client: BadMCPClient)

    assert {:error,
            %Connect.Error.ProviderError{
              provider: :mcp,
              reason: :invalid_response,
              details: %{response: "bad_response"}
            }} =
             Jido.Connect.MCP.Actions.ListTools.run(
               %{endpoint_id: "filesystem", timeout: 1_000},
               action_context(context, lease)
             )
  end

  test "MCP client exceptions normalize to provider errors" do
    {context, lease} = context_and_lease(mcp_client: RaisingMCPClient)

    assert {:error,
            %Connect.Error.ProviderError{
              provider: :mcp,
              reason: :client_exception,
              details: %{module: RaisingMCPClient, function: :list_tools}
            }} =
             Jido.Connect.MCP.Actions.ListTools.run(
               %{endpoint_id: "filesystem", timeout: 1_000},
               action_context(context, lease)
             )
  end

  test "unknown MCP endpoint returns validation error after scope policy passes" do
    {context, lease} =
      context_and_lease(
        scopes: [
          "mcp:tools:list",
          "mcp:endpoint:*"
        ]
      )

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :unknown_mcp_endpoint,
              subject: "missing"
            }} =
             Jido.Connect.MCP.Actions.ListTools.run(
               %{endpoint_id: "missing"},
               action_context(context, lease)
             )
  end

  test "static host clients resolve through the bridge" do
    register_client!(:runtime_registered, FakeMCPClient)

    assert {:ok, :runtime_registered} =
             Jido.Connect.MCP.EndpointResolver.resolve("runtime_registered")
  end

  test "prepared commit routes a host-owned client reference through Connect" do
    scopes = ["mcp:tools:call", "mcp:endpoint:slack", "mcp:tool:post_message"]

    connection =
      Connect.Connection.new!(%{
        id: "slack-persona-a",
        provider: :mcp,
        profile: :endpoint,
        tenant_id: "tenant_1",
        owner_type: :tenant,
        owner_id: "tenant_1",
        status: :connected,
        scopes: scopes,
        metadata: %{mcp_endpoint_id: "slack", connection_revision: 1}
      })

    context =
      Connect.Context.new!(%{
        tenant_id: "tenant_1",
        actor: %{id: "persona_a", type: :agent},
        connection: connection
      })

    lease =
      Connect.CredentialLease.from_connection!(
        connection,
        %{
          mcp_client_module: HostMCPClient,
          mcp_client_ref: Jido.Connect.MCP.HostEndpoint.internal_id(connection),
          mcp_endpoint: %{
            transport: {:stdio, [command: "echo"]},
            client_info: %{name: "wayfinder-connect-test"}
          }
        },
        expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
        metadata: %{credential_version: 1}
      )

    input = %{
      endpoint_id: "slack",
      tool_name: "post_message",
      arguments: %{"text" => "hello"},
      expected_schema_hash:
        Jido.Connect.MCP.Tool.schema_hash(%{
          "type" => "object",
          "properties" => %{"text" => %{"type" => "string"}}
        }),
      timeout: 1_000
    }

    assert {:ok, prepared} =
             Connect.prepare(Jido.Connect.MCP, "mcp.tool.call", input,
               context: context,
               credential_lease: lease,
               policy: AllowPolicy,
               binding_ref: "persona-binding-a"
             )

    assert prepared.confirmation_required?
    refute_received {:host_mcp_called, _endpoint_id, _text, _opts}

    authorization = %{plan_id: prepared.id, approved_by: "user_1"}

    assert {:ok,
            %{
              result: %{
                endpoint_id: "slack",
                tool_name: "post_message",
                content: [%{"text" => "sent"}]
              }
            }} =
             Connect.commit(Jido.Connect.MCP, prepared, input,
               context: context,
               credential_lease: lease,
               policy: AllowPolicy,
               binding_ref: "persona-binding-a",
               execution_authorization: authorization,
               authorization_validator: fn evidence, plan, commit_context ->
                 evidence.plan_id == plan.id and commit_context.actor.id == "persona_a"
               end
             )

    internal_id = Jido.Connect.MCP.HostEndpoint.internal_id(connection)
    assert_received {:host_mcp_discovered, ^internal_id, [timeout: 1_000]}
    assert_received {:host_mcp_called, ^internal_id, "hello", [timeout: 1_000]}
    assert :ok = Jido.Connect.MCP.EndpointLeaseManager.force_stop(connection)
  end

  test "prepared commit rejects MCP tool schema drift before calling the tool" do
    {context, lease} = host_context_and_lease("slack-schema-drift")

    input = %{
      endpoint_id: "slack",
      tool_name: "post_message",
      arguments: %{"text" => "hello"},
      expected_schema_hash: String.duplicate("0", 64),
      timeout: 1_000
    }

    assert {:ok, prepared} =
             Connect.prepare(Jido.Connect.MCP, "mcp.tool.call", input,
               context: context,
               credential_lease: lease,
               policy: AllowPolicy,
               binding_ref: "persona-binding-drift"
             )

    assert {:error, %Connect.Error.ValidationError{reason: :mcp_tool_schema_changed}} =
             Connect.commit(Jido.Connect.MCP, prepared, input,
               context: context,
               credential_lease: lease,
               policy: AllowPolicy,
               binding_ref: "persona-binding-drift",
               execution_authorization: %{plan_id: prepared.id},
               authorization_validator: fn evidence, plan, _context ->
                 evidence.plan_id == plan.id
               end
             )

    internal_id = Jido.Connect.MCP.HostEndpoint.internal_id(context.connection)
    assert_received {:host_mcp_discovered, ^internal_id, [timeout: 1_000]}
    refute_received {:host_mcp_called, ^internal_id, _text, _opts}
    assert :ok = Jido.Connect.MCP.EndpointLeaseManager.force_stop(context.connection)
  end

  test "scope resolver rejects ungranted tools before handler execution" do
    {context, lease} = context_and_lease(scopes: ["mcp:tools:call", "mcp:endpoint:filesystem"])

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: ["mcp:tool:write_file"]
            }} =
             Jido.Connect.MCP.Actions.CallTool.run(
               %{
                 endpoint_id: "filesystem",
                 tool_name: "write_file",
                 arguments: %{},
                 timeout: 1_000
               },
               action_context(context, lease)
             )
  end

  test "generated plugin filters actions and reports availability" do
    spec = Jido.Connect.MCP.Plugin.plugin_spec(%{})

    assert spec.actions == [
             Jido.Connect.MCP.Actions.ListTools,
             Jido.Connect.MCP.Actions.CallTool
           ]

    filtered =
      Jido.Connect.MCP.Plugin.plugin_spec(%{
        allowed_actions: ["mcp.tools.list"]
      })

    assert filtered.actions == [Jido.Connect.MCP.Actions.ListTools]

    {context, _lease} = context_and_lease()

    [available | _] =
      Jido.Connect.MCP.Plugin.tool_availability(%{
        connection: context.connection,
        integration_context: context,
        policy: AllowPolicy
      })

    assert available.state == :available

    [missing_scopes | _] =
      Jido.Connect.MCP.Plugin.tool_availability(%{
        connection: %{context.connection | scopes: []},
        integration_context: context,
        policy: AllowPolicy
      })

    assert missing_scopes.state == :missing_scopes
    assert missing_scopes.missing_scopes == ["mcp:tools:list"]
  end

  defp context_and_lease(opts \\ []) do
    register_client!(:filesystem, Keyword.get(opts, :mcp_client, FakeMCPClient))

    scopes =
      Keyword.get(opts, :scopes, [
        "mcp:tools:list",
        "mcp:tools:call",
        "mcp:endpoint:filesystem",
        "mcp:tool:read_text_file"
      ])

    connection =
      Connect.Connection.new!(%{
        id: "mcp-filesystem",
        provider: :mcp,
        profile: :endpoint,
        tenant_id: "tenant_1",
        owner_type: :tenant,
        owner_id: "tenant_1",
        status: :connected,
        scopes: scopes
      })

    context =
      Connect.Context.new!(%{
        tenant_id: "tenant_1",
        actor: %{id: "user_1", type: :user},
        connection: connection
      })

    lease =
      Connect.CredentialLease.new!(%{
        connection_id: "mcp-filesystem",
        expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
        fields: %{}
      })

    {context, lease}
  end

  defp action_context(context, lease) do
    %{integration_context: context, credential_lease: lease, policy: AllowPolicy}
  end

  defp host_context_and_lease(connection_id) do
    scopes = ["mcp:tools:call", "mcp:endpoint:slack", "mcp:tool:post_message"]

    connection =
      Connect.Connection.new!(%{
        id: connection_id,
        provider: :mcp,
        profile: :endpoint,
        tenant_id: "tenant_1",
        owner_type: :tenant,
        owner_id: "tenant_1",
        status: :connected,
        scopes: scopes,
        metadata: %{mcp_endpoint_id: "slack", connection_revision: 1}
      })

    context =
      Connect.Context.new!(%{
        tenant_id: "tenant_1",
        actor: %{id: "persona_drift", type: :agent},
        connection: connection
      })

    lease =
      Connect.CredentialLease.from_connection!(
        connection,
        %{
          mcp_client_module: HostMCPClient,
          mcp_client_ref: Jido.Connect.MCP.HostEndpoint.internal_id(connection),
          mcp_endpoint: %{
            transport: {:stdio, [command: "echo"]},
            client_info: %{name: "wayfinder-connect-test"}
          }
        },
        expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
        metadata: %{credential_version: 1}
      )

    {context, lease}
  end

  defp register_client!(endpoint_id, module) do
    clients = Application.get_env(:jido_connect, :mcp_clients, %{})

    Application.put_env(
      :jido_connect,
      :mcp_clients,
      Map.put(clients, endpoint_id, {module, endpoint_id})
    )
  end
end
