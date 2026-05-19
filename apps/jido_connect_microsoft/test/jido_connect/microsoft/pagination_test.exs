defmodule Jido.Connect.Microsoft.PaginationTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Microsoft.Pagination

  describe "query/2" do
    test "adds pagination options to query maps" do
      result = Pagination.query(%{q: "name"}, page_size: 50)
      assert result.q == "name"
      assert result[:"$top"] == 50
    end

    test "accepts string-keyed options" do
      result = Pagination.query(%{}, %{"page_size" => 25, "skip" => 10})
      assert result[:"$top"] == 25
      assert result[:"$skip"] == 10
    end

    test "omits nil and empty options" do
      result = Pagination.query(%{q: "name"}, page_size: nil)
      assert result == %{q: "name"}
    end

    test "preserves existing query params" do
      result = Pagination.query(%{filter: "active"}, page_size: 10, skip: 20)
      assert result.filter == "active"
      assert result[:"$top"] == 10
      assert result[:"$skip"] == 20
    end

    test "returns base map when no options are given" do
      result = Pagination.query(%{existing: true})
      assert result == %{existing: true}
    end
  end

  describe "next_link/1" do
    test "extracts @odata.nextLink from response body" do
      body = %{"@odata.nextLink" => "https://graph.microsoft.com/v1.0/me/messages?$skip=10"}

      assert Pagination.next_link(body) ==
               "https://graph.microsoft.com/v1.0/me/messages?$skip=10"
    end

    test "returns nil when nextLink is missing" do
      assert Pagination.next_link(%{"value" => []}) == nil
    end

    test "returns nil for non-map inputs" do
      assert Pagination.next_link(:not_a_map) == nil
      assert Pagination.next_link(nil) == nil
      assert Pagination.next_link("string") == nil
    end
  end

  describe "delta_link/1" do
    test "extracts @odata.deltaLink from delta response body" do
      delta_body = %{
        "@odata.deltaLink" => "https://graph.microsoft.com/v1.0/me/messages/delta?$deltaToken=abc"
      }

      assert Pagination.delta_link(delta_body) ==
               "https://graph.microsoft.com/v1.0/me/messages/delta?$deltaToken=abc"
    end

    test "returns nil when deltaLink is missing" do
      body = %{"@odata.nextLink" => "https://graph.microsoft.com/v1.0/me/messages?$skip=10"}
      assert Pagination.delta_link(body) == nil
    end

    test "returns nil for non-map inputs" do
      assert Pagination.delta_link(nil) == nil
    end
  end

  describe "values/1" do
    test "extracts the value array from an OData response" do
      body = %{
        "@odata.context" => "https://graph.microsoft.com/v1.0/$metadata#Collection(message)",
        "value" => [%{"id" => "1"}, %{"id" => "2"}]
      }

      assert Pagination.values(body) == [%{"id" => "1"}, %{"id" => "2"}]
    end

    test "returns empty list when value key is missing" do
      assert Pagination.values(%{"@odata.context" => "..."}) == []
    end

    test "returns empty list when value is not a list" do
      assert Pagination.values(%{"value" => "not a list"}) == []
      assert Pagination.values(%{"value" => 123}) == []
    end

    test "returns empty list for non-map inputs" do
      assert Pagination.values(nil) == []
      assert Pagination.values(:not_a_map) == []
    end

    test "returns empty list for an empty value array" do
      assert Pagination.values(%{"value" => []}) == []
    end
  end

  describe "has_more?/1" do
    test "returns true when @odata.nextLink is present" do
      body = %{
        "@odata.nextLink" => "https://graph.microsoft.com/v1.0/me/messages?$skip=10",
        "value" => [%{"id" => "1"}]
      }

      assert Pagination.has_more?(body) == true
    end

    test "returns false when @odata.nextLink is missing" do
      body = %{"value" => [%{"id" => "1"}]}
      assert Pagination.has_more?(body) == false
    end

    test "returns false when @odata.nextLink is empty string" do
      body = %{"@odata.nextLink" => "", "value" => []}
      assert Pagination.has_more?(body) == false
    end

    test "returns false when @odata.nextLink is nil" do
      body = %{"@odata.nextLink" => nil}
      assert Pagination.has_more?(body) == false
    end

    test "returns false for non-map inputs" do
      assert Pagination.has_more?(nil) == false
      assert Pagination.has_more?(:not_a_map) == false
    end
  end

  describe "checkpoint/2" do
    test "builds checkpoint metadata from a list response body" do
      body = %{
        "@odata.nextLink" => "https://graph.microsoft.com/v1.0/me/messages?$skip=10",
        "value" => [%{"id" => "1"}, %{"id" => "2"}, %{"id" => "3"}]
      }

      checkpoint = Pagination.checkpoint(body, %{seen: 10})

      assert checkpoint.next_link == "https://graph.microsoft.com/v1.0/me/messages?$skip=10"
      assert checkpoint.seen == 10
      assert checkpoint.value_count == 3
    end

    test "includes delta_link when present" do
      body = %{
        "@odata.deltaLink" =>
          "https://graph.microsoft.com/v1.0/me/messages/delta?$deltaToken=abc",
        "value" => [%{"id" => "1"}]
      }

      checkpoint = Pagination.checkpoint(body)

      assert checkpoint.delta_link ==
               "https://graph.microsoft.com/v1.0/me/messages/delta?$deltaToken=abc"

      assert checkpoint.value_count == 1
    end

    test "omits nil fields from checkpoint" do
      body = %{"value" => [%{"id" => "1"}]}

      checkpoint = Pagination.checkpoint(body)

      refute Map.has_key?(checkpoint, :next_link)
      refute Map.has_key?(checkpoint, :delta_link)
      assert checkpoint.value_count == 1
    end

    test "merges extra metadata" do
      body = %{
        "@odata.nextLink" => "https://graph.microsoft.com/v1.0/me/messages?$skip=10",
        "value" => []
      }

      checkpoint =
        Pagination.checkpoint(body, %{
          sync_id: "sync-123",
          product: :outlook
        })

      assert checkpoint.sync_id == "sync-123"
      assert checkpoint.product == :outlook
      assert checkpoint.value_count == 0
    end
  end
end
