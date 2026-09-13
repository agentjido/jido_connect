defmodule Jido.Connect.MCP do
  @moduledoc """
  MCP bridge integration authored with the `Jido.Connect` Spark DSL.

  Core Connect treats MCP as a narrow bridge: remote server credentials and
  transport config stay in host-owned endpoint configuration, while Connect
  models endpoint and tool policy and exposes generated Jido actions.
  """

  use Jido.Connect

  integration do
    id :mcp
    name "MCP"
    description "Bridge configured MCP endpoints into Jido Connect actions."
    category :tool_bridge
    docs ["https://modelcontextprotocol.io"]
  end

  catalog do
    package :jido_connect
    status :experimental
    tags [:mcp, :tool_bridge, :agents]

    metadata %{
      bridge?: true,
      bridge_package: :jido_connect,
      protocol_package: :ex_mcp
    }

    capability :bridge do
      kind :mcp
      feature :mcp_bridge
      label "MCP bridge"
      description "Expose configured MCP endpoints as Jido Connect actions."
      status :experimental
    end
  end

  auth do
    api_key :endpoint do
      default? true
      owner :tenant
      subject :mcp_endpoint
      label "Host-configured MCP endpoint"
      setup :host_configured_endpoint
      credential_fields []
      lease_fields []
      scopes ["mcp:tools:list", "mcp:tools:call", "mcp:endpoint:*", "mcp:tool:*"]
    end
  end

  policies do
    policy :endpoint_access do
      label "Endpoint access"

      description "Host verifies the actor may use the configured MCP endpoint and requested remote tool."

      subject {:input, :endpoint_id}
      owner {:connection, :owner}
      decision :allow_operation
    end
  end

  actions do
    action :list_tools do
      id "mcp.tools.list"
      resource :mcp_tool
      verb :list
      data_classification :tool_metadata
      label "List MCP tools"
      description "List tools from a configured MCP endpoint."
      handler Jido.Connect.MCP.Handlers.Actions.ListTools
      effect :read

      access do
        auth :endpoint
        policies [:endpoint_access]
        scopes ["mcp:tools:list"], resolver: Jido.Connect.MCP.ScopeResolver
      end

      input do
        field :endpoint_id, :string, required?: true, example: "filesystem"
        field :timeout, :integer
      end

      output do
        field :endpoint_id, :string
        field :tools, {:array, :map}
      end
    end

    action :call_tool do
      id "mcp.tool.call"
      resource :mcp_tool
      verb :call
      data_classification :external_tool_input
      label "Call MCP tool"
      description "Call an allowlisted tool on a configured MCP endpoint."
      handler Jido.Connect.MCP.Handlers.Actions.CallTool
      effect :external_write, confirmation: :required_for_ai

      access do
        auth :endpoint
        policies [:endpoint_access]
        scopes ["mcp:tools:call"], resolver: Jido.Connect.MCP.ScopeResolver
      end

      input do
        field :endpoint_id, :string, required?: true, example: "filesystem"
        field :tool_name, :string, required?: true, example: "read_text_file"
        field :arguments, :map, default: %{}
        field :expected_schema_hash, :string
        field :timeout, :integer
      end

      output do
        field :result, :map
      end
    end
  end
end
