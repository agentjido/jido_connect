defmodule Jido.Connect.MCP.Handlers.Actions.ListResourceTemplates do
  @moduledoc false
  def run(input, opts),
    do: Jido.Connect.MCP.Runtime.read_operation(:list_resource_templates, input, opts)
end
