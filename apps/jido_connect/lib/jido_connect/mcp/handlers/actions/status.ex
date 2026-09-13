defmodule Jido.Connect.MCP.Handlers.Actions.Status do
  @moduledoc false
  def run(input, opts), do: Jido.Connect.MCP.Runtime.read_operation(:status, input, opts)
end
