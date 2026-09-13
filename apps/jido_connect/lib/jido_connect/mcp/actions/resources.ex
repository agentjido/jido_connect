defmodule Jido.Connect.MCP.Actions.Resources do
  @moduledoc false
  use Spark.Dsl.Fragment, of: Jido.Connect

  actions do
    action :list_resources do
      id "mcp.resources.list"
      resource :mcp_resource
      verb :list
      data_classification :workspace_content
      label "List MCP resources"
      description "List MCP resources through an authorized endpoint."
      handler Jido.Connect.MCP.Handlers.Actions.ListResources
      effect :read

      access do
        auth :endpoint
        policies [:endpoint_access]
        scopes ["mcp:resources:list"], resolver: Jido.Connect.MCP.ScopeResolver
      end

      input do
        field :endpoint_id, :string, required?: true, min_length: 1, max_length: 255
        field :timeout, :integer, minimum: 1, maximum: 120_000
        field :cursor, :string, max_length: 4096
      end

      output do
        field :endpoint_id, :string
        field :result, :map
      end
    end

    action :list_resource_templates do
      id "mcp.resource_templates.list"
      resource :mcp_resource_template
      verb :list
      data_classification :workspace_content
      label "List MCP resource templates"
      description "List MCP resource templates through an authorized endpoint."
      handler Jido.Connect.MCP.Handlers.Actions.ListResourceTemplates
      effect :read

      access do
        auth :endpoint
        policies [:endpoint_access]
        scopes ["mcp:resources:list"], resolver: Jido.Connect.MCP.ScopeResolver
      end

      input do
        field :endpoint_id, :string, required?: true, min_length: 1, max_length: 255
        field :timeout, :integer, minimum: 1, maximum: 120_000
        field :cursor, :string, max_length: 4096
      end

      output do
        field :endpoint_id, :string
        field :result, :map
      end
    end

    action :read_resource do
      id "mcp.resource.read"
      resource :mcp_resource
      verb :read
      data_classification :workspace_content
      label "Read MCP resource"
      description "Read MCP resource through an authorized endpoint."
      handler Jido.Connect.MCP.Handlers.Actions.ReadResource
      effect :read

      access do
        auth :endpoint
        policies [:endpoint_access]
        scopes ["mcp:resources:read"], resolver: Jido.Connect.MCP.ScopeResolver
      end

      input do
        field :endpoint_id, :string, required?: true, min_length: 1, max_length: 255
        field :timeout, :integer, minimum: 1, maximum: 120_000
        field :uri, :string, required?: true, max_length: 4096
      end

      output do
        field :endpoint_id, :string
        field :result, :map
      end
    end
  end
end
