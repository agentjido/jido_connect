defmodule Jido.Connect.Intercom.ScopeResolver do
  @moduledoc """
  Resolves Intercom OAuth scopes.

  Each action maps to the narrowest set of Intercom scopes required.
  The resolver is consulted by the `access` block at runtime.
  """

  @scope_map %{
    "intercom.contact.list" => ["contacts:read"],
    "intercom.contact.search" => ["contacts:read"],
    "intercom.contact.get" => ["contacts:read"],
    "intercom.contact.create" => ["contacts:write"],
    "intercom.contact.update" => ["contacts:write"],
    "intercom.contact.tag" => ["tags:write", "contacts:write"],
    "intercom.contact.untag" => ["tags:write", "contacts:write"],
    "intercom.conversation.list" => ["conversations:read"],
    "intercom.conversation.search" => ["conversations:read"],
    "intercom.conversation.get" => ["conversations:read"],
    "intercom.conversation.reply" => ["conversations:write"],
    "intercom.conversation.add_note" => ["conversations:write"],
    "intercom.conversation.assign" => ["conversations:write"],
    "intercom.admin.list" => ["admins:read"],
    "intercom.team.list" => ["admins:read"]
  }

  @doc """
  Returns the least-privilege Intercom scopes for the given operation.
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
