defmodule Jido.Connect.Asana.ScopeResolver do
  @moduledoc """
  Resolves Asana scopes for action authorization.

  Asana scopes are flat strings (`default`, `read`, `write`).
  The resolver maps operation IDs to the minimum required scopes.

  Action fragments have not been added yet; the resolver returns sensible
  defaults and will be extended as actions are implemented.
  """

  @spec required_scopes(term(), term(), term()) :: [String.t()]
  def required_scopes(operation, _input, _connection) do
    operation
    |> operation_id()
    |> scopes_for_operation()
  end

  defp operation_id(nil), do: nil
  defp operation_id(%{id: id}), do: id
  defp operation_id(%{action_id: action_id}), do: action_id
  defp operation_id(operation), do: Map.get(operation, :id)

  defp scopes_for_operation(nil), do: ["default"]

  defp scopes_for_operation(_operation_id) do
    # Default scope for all operations until action fragments define specifics.
    ["default"]
  end
end
