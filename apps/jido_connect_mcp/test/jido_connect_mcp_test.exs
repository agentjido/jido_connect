defmodule Jido.Connect.MCPTest do
  use ExUnit.Case

  alias Jido.Connect

  defmodule FakeMCPClient do
    def list_tools(:filesystem) do
      {:ok,
       %{
         data: %{
           "tools" => [
             %{
               name: "read_text_file",
               description: "Read a text file without a timeout",
               inputSchema: %{"type" => "object"}
             }
           ]
         }
       }}
    end

    def list_tools(:filesystem, opts) do
      assert opts[:timeout] == 1_000

      {:ok,
       %{
         status: :ok,
         data: %{
           "tools" => [
             %{
               "name" => "read_text_file",
               "description" => "Read a text file",
               "inputSchema" => %{"type" => "object"},
               "annotations" => %{"readOnlyHint" => true}
             }
           ]
         }
       }}
    end

    def call_tool(:filesystem, "read_text_file", %{"path" => "/tmp/readme.md"}, opts) do
      assert opts[:timeout] == 1_000

      {:ok,
       %{
         status: :ok,
         data: %{
           "content" => [%{"type" => "text", "text" => "hello"}]
         }
       }}
    end

    def call_tool(:filesystem, "fail", %{}, opts) do
      assert opts[:timeout] == 1_000
      {:error, %{type: :transport, message: "transport failed"}}
    end
  end

  defmodule BadMCPClient do
    def list_tools(:filesystem, _opts), do: :bad_response
  end

  defmodule RaisingMCPClient do
    def list_tools(:filesystem, _opts), do: raise("mcp exploded")
  end

  defmodule HostMCPClient do
    def list_tools(endpoint_id, opts) do
      send(self(), {:host_mcp_discovered, endpoint_id, opts})

      {:ok,
       %{
         status: :ok,
         data: %{
           "tools" => [
             %{
               "name" => "post_message",
               "inputSchema" => %{
                 "type" => "object",
                 "properties" => %{"text" => %{"type" => "string"}}
               }
             }
           ]
         }
       }}
    end

    def call_tool(endpoint_id, "post_message", %{"text" => text}, opts) do
      send(self(), {:host_mcp_called, endpoint_id, text, opts})

      {:ok,
       %{
         status: :ok,
         data: %{"content" => [%{"type" => "text", "text" => "sent"}]}
       }}
    end
  end

  setup do
    register_endpoint!(:filesystem)

    :ok
  end

  test "MCP integration declares bridge actions" do
    spec = Jido.Connect.MCP.integration()

    assert spec.id == :mcp
    assert spec.package == :jido_connect_mcp
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

    assert entry.package == :jido_connect_mcp
    assert entry.status == :experimental
    assert MapSet.member?(features, :api_key)
    assert MapSet.member?(features, :generated_jido_actions)
    assert MapSet.member?(features, :mcp_bridge)
  end

  test "MCP integration compiles generated Jido modules" do
    assert Application.get_env(:jido_connect_mcp, :jido_connect_providers) == [
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
             package: :jido_connect_mcp,
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

  test "generated list tools action delegates through Jido MCP" do
    {context, lease} = context_and_lease()

    assert {:ok, %{endpoint_id: "filesystem", tools: [tool]}} =
             Jido.Connect.MCP.Actions.ListTools.run(
               %{endpoint_id: "filesystem", timeout: 1_000},
               %{integration_context: context, credential_lease: lease}
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
               %{integration_context: context, credential_lease: lease}
             )

    assert tool.description == "Read a text file without a timeout"
  end

  test "generated call tool action delegates through Jido MCP" do
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
               %{integration_context: context, credential_lease: lease}
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
               %{integration_context: context, credential_lease: lease}
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
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "MCP client exceptions normalize to provider errors" do
    {context, lease} = context_and_lease(mcp_client: RaisingMCPClient)

    assert {:error,
            %Connect.Error.ProviderError{
              provider: :mcp,
              reason: :client_exception,
              details: %{message: "mcp exploded"}
            }} =
             Jido.Connect.MCP.Actions.ListTools.run(
               %{endpoint_id: "filesystem", timeout: 1_000},
               %{integration_context: context, credential_lease: lease}
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
               %{integration_context: context, credential_lease: lease}
             )
  end

  test "runtime registered MCP endpoints resolve through the bridge" do
    register_endpoint!(:runtime_registered)

    assert {:ok, :runtime_registered} =
             Jido.Connect.MCP.EndpointResolver.resolve("runtime_registered")
  end

  test "prepared commit routes a host-owned endpoint through Jido MCP" do
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
        metadata: %{mcp_endpoint_id: "slack"}
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
          mcp_client: HostMCPClient,
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
               binding_ref: "persona-binding-a",
               execution_authorization: authorization,
               authorization_validator: fn evidence, plan, commit_context ->
                 evidence.plan_id == plan.id and commit_context.actor.id == "persona_a"
               end
             )

    internal_id = Jido.Connect.MCP.HostEndpoint.internal_id(connection)
    assert_received {:host_mcp_discovered, ^internal_id, [timeout: 1_000]}
    assert_received {:host_mcp_called, ^internal_id, "hello", [timeout: 1_000]}
    assert {:ok, _endpoint} = Jido.MCP.ClientPool.fetch_endpoint(internal_id)
    assert {:ok, _endpoint} = Jido.MCP.unregister_endpoint(internal_id)
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
               binding_ref: "persona-binding-drift"
             )

    assert {:error, %Connect.Error.ValidationError{reason: :mcp_tool_schema_changed}} =
             Connect.commit(Jido.Connect.MCP, prepared, input,
               context: context,
               credential_lease: lease,
               binding_ref: "persona-binding-drift",
               execution_authorization: %{plan_id: prepared.id},
               authorization_validator: fn evidence, plan, _context ->
                 evidence.plan_id == plan.id
               end
             )

    internal_id = Jido.Connect.MCP.HostEndpoint.internal_id(context.connection)
    assert_received {:host_mcp_discovered, ^internal_id, [timeout: 1_000]}
    refute_received {:host_mcp_called, ^internal_id, _text, _opts}
    assert {:ok, _endpoint} = Jido.MCP.unregister_endpoint(internal_id)
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
               %{integration_context: context, credential_lease: lease}
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

    [available | _] =
      Jido.Connect.MCP.Plugin.tool_availability(%{
        connection: elem(context_and_lease(), 0).connection
      })

    assert available.state == :available

    [missing_scopes | _] =
      Jido.Connect.MCP.Plugin.tool_availability(%{
        connection: %{elem(context_and_lease(), 0).connection | scopes: []}
      })

    assert missing_scopes.state == :missing_scopes
    assert missing_scopes.missing_scopes == ["mcp:tools:list"]
  end

  defp context_and_lease(opts \\ []) do
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
        fields: %{mcp_client: Keyword.get(opts, :mcp_client, FakeMCPClient)}
      })

    {context, lease}
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
        metadata: %{mcp_endpoint_id: "slack"}
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
          mcp_client: HostMCPClient,
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

  defp register_endpoint!(endpoint_id) do
    {:ok, endpoint} =
      Jido.MCP.Endpoint.new(endpoint_id, %{
        transport: {:stdio, [command: "echo"]},
        client_info: %{name: "jido-connect-mcp-test"}
      })

    case Jido.MCP.register_endpoint(endpoint) do
      {:ok, _endpoint} -> :ok
      {:error, {:endpoint_already_registered, ^endpoint_id}} -> :ok
    end
  end
end
