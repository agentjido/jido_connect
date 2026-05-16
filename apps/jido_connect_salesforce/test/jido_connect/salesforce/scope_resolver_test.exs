defmodule Jido.Connect.Salesforce.ScopeResolverTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Salesforce.ScopeResolver

  describe "contact scopes" do
    test "returns api scope for get_contact" do
      assert ScopeResolver.required_scopes(%{id: "salesforce.contacts.contact.get"}, %{}, %{}) ==
               ["api"]
    end

    test "returns api scope for list_contacts" do
      assert ScopeResolver.required_scopes(%{id: "salesforce.contacts.contact.list"}, %{}, %{}) ==
               ["api"]
    end

    test "returns api scope for create_contact" do
      assert ScopeResolver.required_scopes(%{id: "salesforce.contacts.contact.create"}, %{}, %{}) ==
               ["api"]
    end
  end

  test "returns empty scopes for unknown operations" do
    assert ScopeResolver.required_scopes(%{id: "salesforce.accounts.account.get"}, %{}, %{}) == []
    assert ScopeResolver.required_scopes(%{}, %{}, %{}) == []
  end

  test "exposes required_scopes/3" do
    assert {:module, ScopeResolver} = Code.ensure_loaded(ScopeResolver)
    assert function_exported?(ScopeResolver, :required_scopes, 3)
  end

  describe "scope matrix" do
    test "maps every operation to the narrowest required scope" do
      assert_scope_matrix([
        %{operation: "salesforce.contacts.contact.get", expected: ["api"]},
        %{operation: "salesforce.contacts.contact.list", expected: ["api"]},
        %{operation: "salesforce.contacts.contact.create", expected: ["api"]}
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
