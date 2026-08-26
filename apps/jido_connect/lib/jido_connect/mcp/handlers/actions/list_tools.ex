defmodule Jido.Connect.MCP.Handlers.Actions.ListTools do
  @moduledoc false

  def run(input, opts), do: Jido.Connect.MCP.Runtime.list_tools(input, opts)
end
