defmodule Jido.Connect.MCP.ScopeResolver do
  @moduledoc """
  Derives MCP bridge scopes from action input.

  The bridge treats configured MCP endpoints and remote tools as policy
  resources. Hosts can grant a specific endpoint/tool or use the wildcard
  scopes `mcp:endpoint:*` and `mcp:tool:*`.
  """

  alias Jido.Connect.Connection

  def required_scopes(operation, input, connection) do
    granted_scopes =
      case connection do
        %Connection{scopes: scopes} -> scopes
        _other -> []
      end

    static = Map.get(operation, :scopes, [])
    endpoint_scope = resource_scope("mcp:endpoint", input[:endpoint_id], granted_scopes)
    tool_scope = tool_scope(operation_id(operation), input[:tool_name], granted_scopes)

    {:ok, Enum.uniq(static ++ endpoint_scope ++ tool_scope)}
  end

  defp operation_id(operation) do
    Map.get(operation, :id) || Map.get(operation, :action_id) || Map.get(operation, :trigger_id)
  end

  defp resource_scope(_prefix, nil, _granted_scopes), do: []

  defp resource_scope(prefix, value, granted_scopes) do
    wildcard = "#{prefix}:*"
    scoped = "#{prefix}:#{value}"

    if wildcard in granted_scopes, do: [], else: [scoped]
  end

  defp tool_scope("mcp.tool.call", tool_name, granted_scopes) do
    resource_scope("mcp:tool", tool_name, granted_scopes)
  end

  defp tool_scope(_operation_id, _tool_name, _granted_scopes), do: []
end
