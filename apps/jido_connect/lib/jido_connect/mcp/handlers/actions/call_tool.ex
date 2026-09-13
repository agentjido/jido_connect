defmodule Jido.Connect.MCP.Handlers.Actions.CallTool do
  @moduledoc false

  def run(input, opts), do: Jido.Connect.MCP.Runtime.call_tool(input, opts)
end
