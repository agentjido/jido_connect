defmodule Jido.Connect.MCP.Client do
  @moduledoc false

  @type client_ref :: GenServer.server() | term()
  @type result :: {:ok, map()} | {:error, term()}

  @callback list_tools(client_ref(), keyword()) :: result()
  @callback call_tool(client_ref(), String.t(), map(), keyword()) :: result()
  @callback list_resources(client_ref(), keyword()) :: result()
  @callback list_resource_templates(client_ref(), keyword()) :: result()
  @callback read_resource(client_ref(), String.t(), keyword()) :: result()
  @callback list_prompts(client_ref(), keyword()) :: result()
  @callback get_prompt(client_ref(), String.t(), map(), keyword()) :: result()
  @callback complete(client_ref(), map(), map(), keyword()) :: result()
  @callback ping(client_ref(), keyword()) :: result()
  @callback status(client_ref(), keyword()) :: result()
  @optional_callbacks list_resources: 2,
                      list_resource_templates: 2,
                      read_resource: 3,
                      list_prompts: 2,
                      get_prompt: 4,
                      complete: 4,
                      ping: 2,
                      status: 2
end
