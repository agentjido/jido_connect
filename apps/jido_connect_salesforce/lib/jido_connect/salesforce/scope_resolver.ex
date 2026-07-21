defmodule Jido.Connect.Salesforce.ScopeResolver do
  @moduledoc """
  Resolves Salesforce OAuth scopes.

  Each action maps to the narrowest set of Salesforce scopes required.
  The resolver is consulted by the `access` block at runtime.
  """

  @scope_map %{
    # Contact actions
    "salesforce.contacts.contact.get" => ["api"],
    "salesforce.contacts.contact.list" => ["api"],
    "salesforce.contacts.contact.create" => ["api"],
    "salesforce.contacts.contact.update" => ["api"],
    # Lead actions
    "salesforce.crm.lead.create" => ["api"],
    "salesforce.crm.lead.update" => ["api"],
    # Task actions
    "salesforce.crm.task.create" => ["api"],
    "salesforce.crm.task.update" => ["api"],
    # Generic SObject query/read actions
    "salesforce.crm.query" => ["api"],
    "salesforce.crm.record.get" => ["api"],
    "salesforce.crm.record.create" => ["api"],
    "salesforce.crm.record.update" => ["api"],
    "salesforce.crm.object.describe" => ["api"],
    "salesforce.crm.record.list_recent" => ["api"],
    "salesforce.crm.query_more" => ["api"]
  }

  @doc """
  Returns the least-privilege Salesforce scopes for the given operation.
  """
  def required_scopes(operation, _input, _connection) do
    operation
    |> operation_id()
    |> then(&Map.get(@scope_map, &1, []))
  end

  defp operation_id(%{id: id}), do: id
  defp operation_id(%{action_id: action_id}), do: action_id
  defp operation_id(_operation), do: nil
end
