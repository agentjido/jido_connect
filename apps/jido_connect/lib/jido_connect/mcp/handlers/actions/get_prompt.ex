defmodule Jido.Connect.MCP.Handlers.Actions.GetPrompt do
  @moduledoc false
  def run(input, opts), do: Jido.Connect.MCP.Runtime.read_operation(:get_prompt, input, opts)
end
