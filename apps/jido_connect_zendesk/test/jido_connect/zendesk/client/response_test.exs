defmodule Jido.Connect.Zendesk.Client.ResponseTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Zendesk.Client.Response

  describe "handle_ticket_response/1" do
    test "normalizes a single ticket response" do
      resp =
        {:ok,
         %{
           status: 200,
           body: %{
             "ticket" => %{
               "id" => 12345,
               "subject" => "Cannot reset password",
               "status" => "open",
               "priority" => "normal",
               "type" => "incident",
               "tags" => ["password"],
               "created_at" => "2026-03-15T10:30:00Z",
               "updated_at" => "2026-05-10T14:22:00Z"
             }
           }
         }}

      assert {:ok, ticket} = Response.handle_ticket_response(resp)
      assert ticket.id == 12345
      assert ticket.subject == "Cannot reset password"
      assert ticket.status == "open"
      assert ticket.tags == ["password"]
    end

    test "returns error for missing ticket key" do
      resp =
        {:ok,
         %{
           status: 200,
           body: %{"error" => "RecordNotFound"}
         }}

      assert {:error, _} = Response.handle_ticket_response(resp)
    end

    test "returns error for 404 status" do
      resp =
        {:ok,
         %{
           status: 404,
           body: %{"error" => "RecordNotFound", "description" => "Not found"}
         }}

      assert {:error, error} = Response.handle_ticket_response(resp)
      assert error.status == 404
    end
  end

  describe "handle_list_response/2" do
    test "handles list with items and pagination" do
      resp =
        {:ok,
         %{
           status: 200,
           body: %{
             "tickets" => [
               %{"id" => 1, "subject" => "First"},
               %{"id" => 2, "subject" => "Second"}
             ],
             "next_page" => "https://example.zendesk.com/api/v2/tickets.json?page=2",
             "previous_page" => nil,
             "count" => 42
           }
         }}

      assert {:ok, result} = Response.handle_list_response(resp, "tickets")
      assert length(result.items) == 2
      assert result.next_page =~ "page=2"
      assert result.count == 42
    end

    test "returns error for missing list key" do
      resp =
        {:ok,
         %{
           status: 200,
           body: %{"something_else" => []}
         }}

      assert {:error, _} = Response.handle_list_response(resp, "tickets")
    end

    test "returns error for 401 unauthorized" do
      resp =
        {:ok,
         %{
           status: 401,
           body: %{"error" => "Unauthorized", "description" => "Invalid credentials"}
         }}

      assert {:error, error} = Response.handle_list_response(resp, "tickets")
      assert error.status == 401
    end

    test "returns error for 429 rate limited" do
      resp =
        {:ok,
         %{
           status: 429,
           body: %{"error" => "Rate limited", "description" => "Too many requests"}
         }}

      assert {:error, error} = Response.handle_list_response(resp, "tickets")
      assert error.status == 429
    end
  end

  describe "handle_search_response/2" do
    test "handles search results with items" do
      resp =
        {:ok,
         %{
           status: 200,
           body: %{
             "results" => [
               %{"id" => 1, "subject" => "Search result 1"}
             ],
             "next_page" => nil,
             "count" => 1
           }
         }}

      assert {:ok, result} = Response.handle_search_response(resp, "results")
      assert length(result.items) == 1
      assert result.count == 1
    end

    test "returns error for invalid search response" do
      resp =
        {:ok,
         %{
           status: 200,
           body: %{"no_results_key" => []}
         }}

      assert {:error, _} = Response.handle_search_response(resp, "results")
    end

    test "returns error for provider error response" do
      resp =
        {:ok,
         %{
           status: 500,
           body: %{"error" => "InternalServerError"}
         }}

      assert {:error, error} = Response.handle_search_response(resp, "results")
      assert error.status == 500
    end
  end

  describe "handle_map_response/1" do
    test "returns map body on success" do
      resp = {:ok, %{status: 200, body: %{"key" => "value"}}}
      assert {:ok, %{"key" => "value"}} = Response.handle_map_response(resp)
    end

    test "returns error for non-map body on success status" do
      resp = {:ok, %{status: 200, body: "not a map"}}
      assert {:error, _} = Response.handle_map_response(resp)
    end
  end
end
