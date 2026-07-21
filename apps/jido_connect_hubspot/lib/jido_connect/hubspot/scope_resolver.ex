defmodule Jido.Connect.HubSpot.ScopeResolver do
  @moduledoc """
  Resolves HubSpot OAuth scopes.

  Each action maps to the narrowest set of HubSpot CRM scopes required.
  The resolver is consulted by the `access` block at runtime.
  """

  @scope_map %{
    "hubspot.contacts.contact.get" => ["crm.objects.contacts.read"],
    "hubspot.contacts.contact.list" => ["crm.objects.contacts.read"],
    "hubspot.contacts.contact.search" => ["crm.objects.contacts.read"],
    "hubspot.contacts.contact.create" => ["crm.objects.contacts.write"],
    "hubspot.contacts.contact.update" => ["crm.objects.contacts.write"],
    "hubspot.companies.company.get" => ["crm.objects.companies.read"],
    "hubspot.companies.company.list" => ["crm.objects.companies.read"],
    "hubspot.companies.company.search" => ["crm.objects.companies.read"],
    "hubspot.deals.deal.get" => ["crm.objects.deals.read"],
    "hubspot.deals.deal.list" => ["crm.objects.deals.read"],
    "hubspot.deals.deal.search" => ["crm.objects.deals.read"],
    "hubspot.deals.deal.create" => ["crm.objects.deals.write"],
    "hubspot.deals.deal.update" => ["crm.objects.deals.write"],
    "hubspot.notes.note.create" => ["crm.objects.contacts.write", "crm.objects.deals.write"],
    "hubspot.contacts.contact.changed" => ["crm.objects.contacts.read"],
    "hubspot.contacts.contact.changed.push" => ["crm.objects.contacts.read"],
    "hubspot.deals.deal.changed" => ["crm.objects.deals.read"],
    "hubspot.deals.deal.changed.push" => ["crm.objects.deals.read"]
  }

  @doc """
  Returns the least-privilege HubSpot scopes for the given operation.
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
