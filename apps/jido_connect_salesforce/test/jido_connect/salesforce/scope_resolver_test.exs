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

    test "returns api scope for update_contact" do
      assert ScopeResolver.required_scopes(%{id: "salesforce.contacts.contact.update"}, %{}, %{}) ==
               ["api"]
    end
  end

  describe "lead scopes" do
    test "returns api scope for create_lead" do
      assert ScopeResolver.required_scopes(%{id: "salesforce.crm.lead.create"}, %{}, %{}) ==
               ["api"]
    end

    test "returns api scope for update_lead" do
      assert ScopeResolver.required_scopes(%{id: "salesforce.crm.lead.update"}, %{}, %{}) ==
               ["api"]
    end
  end

  describe "task scopes" do
    test "returns api scope for create_task" do
      assert ScopeResolver.required_scopes(%{id: "salesforce.crm.task.create"}, %{}, %{}) ==
               ["api"]
    end

    test "returns api scope for update_task" do
      assert ScopeResolver.required_scopes(%{id: "salesforce.crm.task.update"}, %{}, %{}) ==
               ["api"]
    end
  end

  describe "generic SObject scopes" do
    test "returns api scope for query" do
      assert ScopeResolver.required_scopes(%{id: "salesforce.crm.query"}, %{}, %{}) ==
               ["api"]
    end

    test "returns api scope for get_record" do
      assert ScopeResolver.required_scopes(%{id: "salesforce.crm.record.get"}, %{}, %{}) ==
               ["api"]
    end

    test "returns api scope for describe_object" do
      assert ScopeResolver.required_scopes(%{id: "salesforce.crm.object.describe"}, %{}, %{}) ==
               ["api"]
    end

    test "returns api scope for list_recent" do
      assert ScopeResolver.required_scopes(%{id: "salesforce.crm.record.list_recent"}, %{}, %{}) ==
               ["api"]
    end

    test "returns api scope for query_more" do
      assert ScopeResolver.required_scopes(%{id: "salesforce.crm.query_more"}, %{}, %{}) ==
               ["api"]
    end
  end

  test "returns empty scopes for unknown operations" do
    assert ScopeResolver.required_scopes(%{id: "salesforce.unknown.action"}, %{}, %{}) == []
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
        %{operation: "salesforce.contacts.contact.create", expected: ["api"]},
        %{operation: "salesforce.contacts.contact.update", expected: ["api"]},
        %{operation: "salesforce.crm.lead.create", expected: ["api"]},
        %{operation: "salesforce.crm.lead.update", expected: ["api"]},
        %{operation: "salesforce.crm.task.create", expected: ["api"]},
        %{operation: "salesforce.crm.task.update", expected: ["api"]},
        %{operation: "salesforce.crm.query", expected: ["api"]},
        %{operation: "salesforce.crm.record.get", expected: ["api"]},
        %{operation: "salesforce.crm.record.create", expected: ["api"]},
        %{operation: "salesforce.crm.record.update", expected: ["api"]},
        %{operation: "salesforce.crm.object.describe", expected: ["api"]},
        %{operation: "salesforce.crm.record.list_recent", expected: ["api"]},
        %{operation: "salesforce.crm.query_more", expected: ["api"]}
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
