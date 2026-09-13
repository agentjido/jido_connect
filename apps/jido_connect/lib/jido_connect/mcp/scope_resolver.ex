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

    with :ok <- validate_completion(operation_id(operation), input) do
      {:ok,
       Enum.uniq(static ++ endpoint_scope ++ tool_scope ++ content_scopes(input, granted_scopes))}
    end
  end

  defp validate_completion("mcp.completion.complete", %{ref: ref, argument: argument})
       when is_map(ref) and is_map(argument) do
    target =
      case Jido.Connect.Data.get(ref, :type) do
        "ref/prompt" -> Jido.Connect.Data.get(ref, :name)
        "ref/resource" -> Jido.Connect.Data.get(ref, :uri)
        _ -> nil
      end

    if is_binary(target) and byte_size(target) in 1..4096 and
         is_binary(Jido.Connect.Data.get(argument, :name)) and
         is_binary(Jido.Connect.Data.get(argument, :value)) do
      :ok
    else
      {:error,
       Jido.Connect.Error.validation("Invalid MCP completion reference or argument",
         reason: :invalid_mcp_completion
       )}
    end
  end

  defp validate_completion("mcp.completion.complete", _),
    do:
      {:error,
       Jido.Connect.Error.validation("Invalid MCP completion input",
         reason: :invalid_mcp_completion
       )}

  defp validate_completion(_, _), do: :ok

  defp content_scopes(input, granted) do
    resource_scope("mcp:resource", input[:uri], granted) ++
      resource_scope("mcp:prompt", input[:prompt_name], granted) ++
      completion_scopes(input[:ref], granted)
  end

  defp completion_scopes(ref, granted) when is_map(ref) do
    case Jido.Connect.Data.get(ref, :type) do
      "ref/prompt" -> resource_scope("mcp:prompt", Jido.Connect.Data.get(ref, :name), granted)
      "ref/resource" -> resource_scope("mcp:resource", Jido.Connect.Data.get(ref, :uri), granted)
      _ -> []
    end
  end

  defp completion_scopes(_, _), do: []

  defp operation_id(operation) do
    Map.get(operation, :id) || Map.get(operation, :action_id) || Map.get(operation, :trigger_id)
  end

  defp resource_scope(_prefix, nil, _granted_scopes), do: []

  defp resource_scope(prefix, value, granted_scopes) do
    wildcard = "#{prefix}:*"
    scoped = "#{prefix}:#{value}"

    if wildcard in granted_scopes, do: [wildcard], else: [scoped]
  end

  defp tool_scope("mcp.tool.call", tool_name, granted_scopes) do
    resource_scope("mcp:tool", tool_name, granted_scopes)
  end

  defp tool_scope(_operation_id, _tool_name, _granted_scopes), do: []
end
