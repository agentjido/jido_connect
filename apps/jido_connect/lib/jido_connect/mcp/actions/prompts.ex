defmodule Jido.Connect.MCP.Actions.Prompts do
  @moduledoc false
  use Spark.Dsl.Fragment, of: Jido.Connect

  actions do
    action :list_prompts do
      id "mcp.prompts.list"
      resource :mcp_prompt
      verb :list
      data_classification :workspace_content
      label "List MCP prompts"
      description "List MCP prompts through an authorized endpoint."
      handler Jido.Connect.MCP.Handlers.Actions.ListPrompts
      effect :read

      access do
        auth :endpoint
        policies [:endpoint_access]
        scopes ["mcp:prompts:list"], resolver: Jido.Connect.MCP.ScopeResolver
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

    action :get_prompt do
      id "mcp.prompt.get"
      resource :mcp_prompt
      verb :get
      data_classification :workspace_content
      label "Get MCP prompt"
      description "Get MCP prompt through an authorized endpoint."
      handler Jido.Connect.MCP.Handlers.Actions.GetPrompt
      effect :read

      access do
        auth :endpoint
        policies [:endpoint_access]
        scopes ["mcp:prompts:get"], resolver: Jido.Connect.MCP.ScopeResolver
      end

      input do
        field :endpoint_id, :string, required?: true, min_length: 1, max_length: 255
        field :timeout, :integer, minimum: 1, maximum: 120_000
        field :prompt_name, :string, required?: true, max_length: 4096
        field :arguments, :map
      end

      output do
        field :endpoint_id, :string
        field :result, :map
      end
    end

    action :complete do
      id "mcp.completion.complete"
      resource :mcp_completion
      verb :get
      data_classification :workspace_content
      label "Complete MCP argument"
      description "Complete MCP argument through an authorized endpoint."
      handler Jido.Connect.MCP.Handlers.Actions.Complete
      effect :read

      access do
        auth :endpoint
        policies [:endpoint_access]
        scopes ["mcp:completion:complete"], resolver: Jido.Connect.MCP.ScopeResolver
      end

      input do
        field :endpoint_id, :string, required?: true, min_length: 1, max_length: 255
        field :timeout, :integer, minimum: 1, maximum: 120_000
        field :ref, :map, required?: true
        field :argument, :map, required?: true
      end

      output do
        field :endpoint_id, :string
        field :result, :map
      end
    end
  end
end
