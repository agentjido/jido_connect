defmodule Jido.Connect.MCP.Handlers.Actions.ReadResource do
  @moduledoc false
  def run(input, opts), do: Jido.Connect.MCP.Runtime.read_operation(:read_resource, input, opts)
end
