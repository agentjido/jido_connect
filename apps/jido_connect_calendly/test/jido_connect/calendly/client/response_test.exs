defmodule Jido.Connect.Calendly.Client.ResponseTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Calendly.Client.Response
  alias Jido.Connect.Error

  describe "handle_list_response/3" do
    test "normalizes successful list response" do
      normalizer = fn body -> {:ok, body["items"]} end

      assert {:ok, ["a", "b"]} =
               Response.handle_list_response(
                 {:ok, %{status: 200, body: %{"items" => ["a", "b"]}}},
                 normalizer,
                 "test_entities"
               )
    end

    test "returns invalid response for malformed body" do
      normalizer = fn _body -> {:error, :bad_data} end

      assert {:error, %Error.ProviderError{provider: :calendly, reason: :invalid_response}} =
               Response.handle_list_response(
                 {:ok, %{status: 200, body: %{"unexpected" => true}}},
                 normalizer,
                 "test_entities"
               )
    end

    test "returns invalid response for non-map body" do
      normalizer = fn body -> {:ok, body} end

      assert {:error, %Error.ProviderError{provider: :calendly, reason: :invalid_response}} =
               Response.handle_list_response(
                 {:ok, %{status: 200, body: []}},
                 normalizer,
                 "test_entities"
               )
    end

    test "delegates error responses to transport" do
      normalizer = fn _body -> {:ok, []} end

      assert {:error, %Error.ProviderError{provider: :calendly}} =
               Response.handle_list_response(
                 {:ok, %{status: 401, body: %{"message" => "Unauthorized"}}},
                 normalizer,
                 "test_entities"
               )
    end

    test "handles runtime error responses" do
      normalizer = fn _body -> {:ok, []} end

      assert {:error, %Error.ProviderError{provider: :calendly}} =
               Response.handle_list_response(
                 {:error, %RuntimeError{message: "timeout"}},
                 normalizer,
                 "test_entities"
               )
    end
  end

  describe "handle_entity_response/3" do
    test "normalizes successful entity response" do
      normalizer = fn body -> {:ok, body["data"]} end

      assert {:ok, %{"id" => 1}} =
               Response.handle_entity_response(
                 {:ok, %{status: 200, body: %{"data" => %{"id" => 1}}}},
                 normalizer,
                 "test_entity"
               )
    end

    test "returns invalid response for malformed body" do
      normalizer = fn _body -> {:error, :bad_data} end

      assert {:error, %Error.ProviderError{provider: :calendly, reason: :invalid_response}} =
               Response.handle_entity_response(
                 {:ok, %{status: 200, body: %{"unexpected" => true}}},
                 normalizer,
                 "test_entity"
               )
    end

    test "returns invalid response for non-map body" do
      normalizer = fn body -> {:ok, body} end

      assert {:error, %Error.ProviderError{provider: :calendly, reason: :invalid_response}} =
               Response.handle_entity_response(
                 {:ok, %{status: 200, body: "string body"}},
                 normalizer,
                 "test_entity"
               )
    end

    test "delegates error responses to transport" do
      normalizer = fn _body -> {:ok, nil} end

      assert {:error, %Error.ProviderError{provider: :calendly}} =
               Response.handle_entity_response(
                 {:ok, %{status: 429, body: %{"message" => "Rate limited"}}},
                 normalizer,
                 "test_entity"
               )
    end

    test "handles runtime error responses" do
      normalizer = fn _body -> {:ok, nil} end

      assert {:error, %Error.ProviderError{provider: :calendly}} =
               Response.handle_entity_response(
                 {:error, %RuntimeError{message: "network error"}},
                 normalizer,
                 "test_entity"
               )
    end
  end

  describe "handle_delete_response/2" do
    test "handles 204 No Content" do
      assert {:ok, %{deleted: true, entity: "webhook_subscription"}} =
               Response.handle_delete_response(
                 {:ok, %{status: 204}},
                 "webhook_subscription"
               )
    end

    test "handles 200 with body" do
      assert {:ok, %{deleted: true, entity: "webhook_subscription", body: body}} =
               Response.handle_delete_response(
                 {:ok, %{status: 200, body: %{"message" => "deleted"}}},
                 "webhook_subscription"
               )

      assert body == %{"message" => "deleted"}
    end

    test "handles 200 without map body" do
      assert {:ok, %{deleted: true, entity: "webhook_subscription"}} =
               Response.handle_delete_response(
                 {:ok, %{status: 200}},
                 "webhook_subscription"
               )
    end

    test "delegates error responses to transport" do
      assert {:error, %Error.ProviderError{provider: :calendly}} =
               Response.handle_delete_response(
                 {:ok, %{status: 404, body: %{"message" => "Not found"}}},
                 "webhook_subscription"
               )
    end
  end
end
