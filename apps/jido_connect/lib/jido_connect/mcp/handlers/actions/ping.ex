defmodule Jido.Connect.MCP.Handlers.Actions.Ping do
  @moduledoc false
  def run(input, opts), do: Jido.Connect.MCP.Runtime.read_operation(:ping, input, opts)
end
