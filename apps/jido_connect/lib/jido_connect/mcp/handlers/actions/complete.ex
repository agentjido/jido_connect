defmodule Jido.Connect.MCP.Handlers.Actions.Complete do
  @moduledoc false
  def run(input, opts), do: Jido.Connect.MCP.Runtime.read_operation(:complete, input, opts)
end
