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
end
