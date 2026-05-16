defmodule Jido.Connect.Airtable.ScopeResolver do
  @moduledoc """
  Resolves Airtable OAuth scopes.

  Each action maps to the narrowest set of Airtable API scopes required.
  The resolver is consulted by the `access` block at runtime.
  """

  @scope_map %{
    "airtable.bases.list" => ["schema.bases:read"],
    "airtable.bases.get" => ["schema.bases:read"],
    "airtable.records.list" => ["data.records:read"],
    "airtable.records.get" => ["data.records:read"],
    "airtable.records.create" => ["data.records:write"],
    "airtable.records.update" => ["data.records:write"],
    "airtable.records.delete" => ["data.records:write"]
  }

  @doc """
  Returns the least-privilege Airtable scopes for the given operation.
  """
  def required_scopes(operation, _input, _connection) do
    operation
    |> operation_id()
    |> then(&Map.get(@scope_map, &1, []))
  end

  defp operation_id(%{id: id}), do: id
  defp operation_id(%{action_id: action_id}), do: action_id
  defp operation_id(operation), do: Map.get(operation, :id)
end
