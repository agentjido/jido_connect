defmodule Jido.Connect.Intercom.Client.ResponseTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Intercom.Client.Response

  describe "handle_list_response/2" do
    test "returns items and pagination for valid list response" do
      body = %{
        "type" => "list",
        "data" => [%{"id" => "1", "type" => "contact"}],
        "total_count" => 30,
        "pages" => %{
          "type" => "pages",
          "next" => %{"page" => 2},
          "page" => 1,
          "per_page" => 20,
          "total_pages" => 2
        }
      }

      response = {:ok, %{status: 200, body: body}}

      assert {:ok, result} = Response.handle_list_response(response, "data")
      assert length(result.items) == 1
      assert result.pagination != nil
      assert result.pagination.page == 1
      assert result.pagination.total_count == 30
    end

    test "returns error for missing key" do
      body = %{"type" => "list"}
      response = {:ok, %{status: 200, body: body}}

      assert {:error, error} = Response.handle_list_response(response, "data")
      assert error.reason == :invalid_response
    end

    test "returns error for non-200 status" do
      response = {:ok, %{status: 401, body: %{"type" => "error.list"}}}

      assert {:error, error} = Response.handle_list_response(response, "data")
      assert error.status == 401
      assert error.provider == :intercom
    end
  end

  describe "handle_search_response/2" do
    test "returns items, pagination, and total_count for valid search response" do
      body = %{
        "type" => "list",
        "data" => [%{"id" => "1"}],
        "total_count" => 5,
        "pages" => %{"page" => 1, "per_page" => 20}
      }

      response = {:ok, %{status: 200, body: body}}

      assert {:ok, result} = Response.handle_search_response(response, "data")
      assert length(result.items) == 1
      assert result.total_count == 5
    end
  end

  describe "handle_single_response/3" do
    test "returns normalized item for valid response" do
      body = %{
        "type" => "contact",
        "contact" => %{
          "id" => "661240",
          "name" => "Alice",
          "type" => "contact"
        }
      }

      response = {:ok, %{status: 200, body: body}}

      normalizer = fn item -> {:ok, item} end

      assert {:ok, result} = Response.handle_single_response(response, "contact", normalizer)
      assert result["id"] == "661240"
    end

    test "returns error for missing key" do
      body = %{"type" => "contact"}
      response = {:ok, %{status: 200, body: body}}
      normalizer = fn item -> {:ok, item} end

      assert {:error, error} = Response.handle_single_response(response, "contact", normalizer)
      assert error.reason == :invalid_response
    end
  end
end
