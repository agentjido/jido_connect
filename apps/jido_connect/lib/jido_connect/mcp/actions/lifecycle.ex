defmodule Jido.Connect.MCP.Actions.Lifecycle do
  @moduledoc false
  use Spark.Dsl.Fragment, of: Jido.Connect

  actions do
    action :ping do
      id "mcp.endpoint.ping"
      resource :mcp_endpoint
      verb :get
      data_classification :workspace_content
      label "Ping MCP endpoint"
      description "Ping MCP endpoint through an authorized endpoint."
      handler Jido.Connect.MCP.Handlers.Actions.Ping
      effect :read

      access do
        auth :endpoint
        policies [:endpoint_access]
        scopes ["mcp:endpoint:inspect"], resolver: Jido.Connect.MCP.ScopeResolver
      end

      input do
        field :endpoint_id, :string, required?: true, min_length: 1, max_length: 255
        field :timeout, :integer, minimum: 1, maximum: 120_000
      end

      output do
        field :endpoint_id, :string
        field :result, :map
      end
    end

    action :status do
      id "mcp.endpoint.status"
      resource :mcp_endpoint
      verb :get
      data_classification :workspace_content
      label "Get MCP endpoint status"
      description "Get MCP endpoint status through an authorized endpoint."
      handler Jido.Connect.MCP.Handlers.Actions.Status
      effect :read

      access do
        auth :endpoint
        policies [:endpoint_access]
        scopes ["mcp:endpoint:inspect"], resolver: Jido.Connect.MCP.ScopeResolver
      end

      input do
        field :endpoint_id, :string, required?: true, min_length: 1, max_length: 255
        field :timeout, :integer, minimum: 1, maximum: 120_000
      end

      output do
        field :endpoint_id, :string
        field :result, :map
      end
    end
  end
end
