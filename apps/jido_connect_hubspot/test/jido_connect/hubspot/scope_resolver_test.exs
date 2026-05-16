defmodule Jido.Connect.HubSpot.ScopeResolverTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.HubSpot.ScopeResolver

  describe "contact read scopes" do
    test "returns contacts read scope for get_contact" do
      assert ScopeResolver.required_scopes(%{id: "hubspot.contacts.contact.get"}, %{}, %{}) ==
               ["crm.objects.contacts.read"]
    end

    test "returns contacts read scope for list_contacts" do
      assert ScopeResolver.required_scopes(%{id: "hubspot.contacts.contact.list"}, %{}, %{}) ==
               ["crm.objects.contacts.read"]
    end

    test "returns contacts read scope for search_contacts" do
      assert ScopeResolver.required_scopes(%{id: "hubspot.contacts.contact.search"}, %{}, %{}) ==
               ["crm.objects.contacts.read"]
    end
  end

  describe "company read scopes" do
    test "returns companies read scope for get_company" do
      assert ScopeResolver.required_scopes(%{id: "hubspot.companies.company.get"}, %{}, %{}) ==
               ["crm.objects.companies.read"]
    end

    test "returns companies read scope for list_companies" do
      assert ScopeResolver.required_scopes(%{id: "hubspot.companies.company.list"}, %{}, %{}) ==
               ["crm.objects.companies.read"]
    end

    test "returns companies read scope for search_companies" do
      assert ScopeResolver.required_scopes(%{id: "hubspot.companies.company.search"}, %{}, %{}) ==
               ["crm.objects.companies.read"]
    end
  end

  describe "deal read scopes" do
    test "returns deals read scope for get_deal" do
      assert ScopeResolver.required_scopes(%{id: "hubspot.deals.deal.get"}, %{}, %{}) ==
               ["crm.objects.deals.read"]
    end

    test "returns deals read scope for list_deals" do
      assert ScopeResolver.required_scopes(%{id: "hubspot.deals.deal.list"}, %{}, %{}) ==
               ["crm.objects.deals.read"]
    end

    test "returns deals read scope for search_deals" do
      assert ScopeResolver.required_scopes(%{id: "hubspot.deals.deal.search"}, %{}, %{}) ==
               ["crm.objects.deals.read"]
    end
  end

  test "returns empty scopes for unknown operations" do
    assert ScopeResolver.required_scopes(%{id: "hubspot.tickets.ticket.get"}, %{}, %{}) == []
    assert ScopeResolver.required_scopes(%{}, %{}, %{}) == []
  end

  test "exposes required_scopes/3" do
    assert {:module, ScopeResolver} = Code.ensure_loaded(ScopeResolver)
    assert function_exported?(ScopeResolver, :required_scopes, 3)
  end

  describe "scope matrix" do
    test "maps every operation to the narrowest required scope" do
      assert_scope_matrix([
        %{operation: "hubspot.contacts.contact.get", expected: ["crm.objects.contacts.read"]},
        %{operation: "hubspot.contacts.contact.list", expected: ["crm.objects.contacts.read"]},
        %{operation: "hubspot.contacts.contact.search", expected: ["crm.objects.contacts.read"]},
        %{operation: "hubspot.companies.company.get", expected: ["crm.objects.companies.read"]},
        %{operation: "hubspot.companies.company.list", expected: ["crm.objects.companies.read"]},
        %{
          operation: "hubspot.companies.company.search",
          expected: ["crm.objects.companies.read"]
        },
        %{operation: "hubspot.deals.deal.get", expected: ["crm.objects.deals.read"]},
        %{operation: "hubspot.deals.deal.list", expected: ["crm.objects.deals.read"]},
        %{operation: "hubspot.deals.deal.search", expected: ["crm.objects.deals.read"]},
        %{operation: "hubspot.contacts.contact.create", expected: ["crm.objects.contacts.write"]},
        %{operation: "hubspot.contacts.contact.update", expected: ["crm.objects.contacts.write"]},
        %{operation: "hubspot.deals.deal.create", expected: ["crm.objects.deals.write"]},
        %{operation: "hubspot.deals.deal.update", expected: ["crm.objects.deals.write"]},
        %{
          operation: "hubspot.notes.note.create",
          expected: ["crm.objects.contacts.write", "crm.objects.deals.write"]
        },
        %{operation: "hubspot.contacts.contact.changed", expected: ["crm.objects.contacts.read"]},
        %{
          operation: "hubspot.contacts.contact.changed.push",
          expected: ["crm.objects.contacts.read"]
        },
        %{operation: "hubspot.deals.deal.changed", expected: ["crm.objects.deals.read"]},
        %{operation: "hubspot.deals.deal.changed.push", expected: ["crm.objects.deals.read"]}
      ])
    end
  end

  defp assert_scope_matrix(matrix) do
    for row <- matrix do
      operation_id = Map.fetch!(row, :operation)
      expected = Map.fetch!(row, :expected)

      assert ScopeResolver.required_scopes(%{id: operation_id}, %{}, %{}) == expected,
             "scope matrix mismatch for #{operation_id}"
    end
  end
end
