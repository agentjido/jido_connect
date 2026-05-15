defmodule Jido.Connect.Google.Slides.ScopeResolver do
  @moduledoc """
  Resolves Google Slides scopes.

  Google Slides exposes both read-only and read-write operations. The resolver
  stays package-local so later action families can preserve least-privilege
  behavior without adding generic Slides scope logic to `jido_connect` core.
  """

  @readonly_scope "https://www.googleapis.com/auth/presentations.readonly"
  @write_scope "https://www.googleapis.com/auth/presentations"

  @write_operations MapSet.new([])

  def required_scopes(operation, _input, _connection) do
    operation
    |> operation_id()
    |> required_for_operation()
  end

  defp required_for_operation(operation_id) do
    if MapSet.member?(@write_operations, operation_id) do
      [@write_scope]
    else
      [@readonly_scope]
    end
  end

  defp operation_id(%{id: id}), do: id
  defp operation_id(%{action_id: action_id}), do: action_id
  defp operation_id(operation), do: Map.get(operation, :id)
end
