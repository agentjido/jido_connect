defmodule Jido.Connect.Airtable.ScopeResolverTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Airtable.ScopeResolver

  describe "base scopes" do
    test "returns schema.bases:read for list_bases" do
      assert ScopeResolver.required_scopes(%{id: "airtable.bases.list"}, %{}, %{}) ==
               ["schema.bases:read"]
    end

    test "returns schema.bases:read for get_base" do
      assert ScopeResolver.required_scopes(%{id: "airtable.bases.get"}, %{}, %{}) ==
               ["schema.bases:read"]
    end
  end

  describe "record read scopes" do
    test "returns data.records:read for list_records" do
      assert ScopeResolver.required_scopes(%{id: "airtable.records.list"}, %{}, %{}) ==
               ["data.records:read"]
    end

    test "returns data.records:read for get_record" do
      assert ScopeResolver.required_scopes(%{id: "airtable.records.get"}, %{}, %{}) ==
               ["data.records:read"]
    end
  end

  describe "record write scopes" do
    test "returns data.records:write for create_record" do
      assert ScopeResolver.required_scopes(%{id: "airtable.records.create"}, %{}, %{}) ==
               ["data.records:write"]
    end

    test "returns data.records:write for update_record" do
      assert ScopeResolver.required_scopes(%{id: "airtable.records.update"}, %{}, %{}) ==
               ["data.records:write"]
    end

    test "returns data.records:write for delete_record" do
      assert ScopeResolver.required_scopes(%{id: "airtable.records.delete"}, %{}, %{}) ==
               ["data.records:write"]
    end
  end

  test "returns empty scopes for unknown operations" do
    assert ScopeResolver.required_scopes(%{id: "airtable.webhooks.create"}, %{}, %{}) == []
    assert ScopeResolver.required_scopes(%{}, %{}, %{}) == []
  end

  test "exposes required_scopes/3" do
    assert {:module, ScopeResolver} = Code.ensure_loaded(ScopeResolver)
    assert function_exported?(ScopeResolver, :required_scopes, 3)
  end

  describe "scope matrix" do
    test "maps every operation to the narrowest required scope" do
      assert_scope_matrix([
        %{operation: "airtable.bases.list", expected: ["schema.bases:read"]},
        %{operation: "airtable.bases.get", expected: ["schema.bases:read"]},
        %{operation: "airtable.records.list", expected: ["data.records:read"]},
        %{operation: "airtable.records.get", expected: ["data.records:read"]},
        %{operation: "airtable.records.create", expected: ["data.records:write"]},
        %{operation: "airtable.records.update", expected: ["data.records:write"]},
        %{operation: "airtable.records.delete", expected: ["data.records:write"]}
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
