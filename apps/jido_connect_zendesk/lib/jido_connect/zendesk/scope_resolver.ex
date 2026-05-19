defmodule Jido.Connect.Zendesk.ScopeResolver do
  @moduledoc """
  Resolves Zendesk OAuth scopes.

  Each action maps to the narrowest set of Zendesk scopes required.
  The resolver is consulted by the `access` block at runtime.
  """

  @scope_map %{
    "zendesk.ticket.list" => ["read", "tickets:read"],
    "zendesk.ticket.search" => ["read", "tickets:read"],
    "zendesk.ticket.get" => ["read", "tickets:read"],
    "zendesk.ticket.create" => ["write", "tickets:write"],
    "zendesk.ticket.update" => ["write", "tickets:write"],
    "zendesk.ticket.comment.list" => ["read", "tickets:read"],
    "zendesk.ticket.comment.add" => ["write", "tickets:write"],
    "zendesk.user.list" => ["read", "users:read"],
    "zendesk.organization.list" => ["read"]
  }

  @doc """
  Returns the least-privilege Zendesk scopes for the given operation.

  Returns an empty list until action fragments are added in a subsequent wave.
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
