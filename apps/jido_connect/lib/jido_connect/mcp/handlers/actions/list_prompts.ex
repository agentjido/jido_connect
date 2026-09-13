defmodule Jido.Connect.MCP.Handlers.Actions.ListPrompts do
  @moduledoc false
  def run(input, opts), do: Jido.Connect.MCP.Runtime.read_operation(:list_prompts, input, opts)
end
