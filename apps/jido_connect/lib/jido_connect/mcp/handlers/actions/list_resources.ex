defmodule Jido.Connect.MCP.Handlers.Actions.ListResources do
  @moduledoc false
  def run(input, opts), do: Jido.Connect.MCP.Runtime.read_operation(:list_resources, input, opts)
end
