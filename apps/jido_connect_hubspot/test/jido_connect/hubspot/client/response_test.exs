defmodule Jido.Connect.HubSpot.Client.ResponseTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.HubSpot.Client.Response
  alias Jido.Connect.HubSpot.Normalizer

  describe "handle_get_response/2" do
    test "returns normalized contact on success" do
      payload = fixture!("contact_common.json")

      response = {:ok, %{status: 200, body: payload}}

      assert {:ok, contact} = Response.handle_get_response(response, &Normalizer.contact/1)
      assert contact.contact_id == "501"
      assert contact.email == "bella@example.com"
    end

    test "returns normalized company on success" do
      payload = fixture!("company_common.json")

      response = {:ok, %{status: 200, body: payload}}

      assert {:ok, company} = Response.handle_get_response(response, &Normalizer.company/1)
      assert company.company_id == "201"
      assert company.name == "Acme Corp"
    end

    test "returns normalized deal on success" do
      payload = fixture!("deal_common.json")

      response = {:ok, %{status: 200, body: payload}}

      assert {:ok, deal} = Response.handle_get_response(response, &Normalizer.deal/1)
      assert deal.deal_id == "301"
      assert deal.deal_name == "Acme Enterprise License"
    end

    test "returns error on HTTP error" do
      response = {:ok, %{status: 404, body: %{"message" => "Not found"}}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :hubspot}} =
               Response.handle_get_response(response, &Normalizer.contact/1)
    end

    test "returns error on transport error" do
      response = {:error, :timeout}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :hubspot}} =
               Response.handle_get_response(response, &Normalizer.contact/1)
    end

    test "returns error on non-map body in success range" do
      response = {:ok, %{status: 200, body: "not a map"}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :hubspot}} =
               Response.handle_get_response(response, &Normalizer.contact/1)
    end
  end

  describe "handle_list_response/2" do
    test "returns normalized contacts with pagination" do
      payload = fixture!("contact_list.json")

      response = {:ok, %{status: 200, body: payload}}

      assert {:ok, result} = Response.handle_list_response(response, &Normalizer.contact/1)
      assert length(result.items) == 2
      assert hd(result.items).contact_id == "501"
      assert result.pagination.after == "502"
    end

    test "returns normalized companies with pagination" do
      payload = fixture!("company_list.json")

      response = {:ok, %{status: 200, body: payload}}

      assert {:ok, result} = Response.handle_list_response(response, &Normalizer.company/1)
      assert length(result.items) == 2
      assert hd(result.items).company_id == "201"
    end

    test "returns normalized deals with pagination" do
      payload = fixture!("deal_list.json")

      response = {:ok, %{status: 200, body: payload}}

      assert {:ok, result} = Response.handle_list_response(response, &Normalizer.deal/1)
      assert length(result.items) == 2
      assert hd(result.items).deal_id == "301"
    end

    test "returns error on HTTP error" do
      response = {:ok, %{status: 401, body: %{"message" => "Unauthorized"}}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :hubspot}} =
               Response.handle_list_response(response, &Normalizer.contact/1)
    end
  end

  describe "handle_search_response/2" do
    test "returns normalized contacts from search" do
      payload = fixture!("contact_search.json")

      response = {:ok, %{status: 200, body: payload}}

      assert {:ok, result} = Response.handle_search_response(response, &Normalizer.contact/1)
      assert length(result.items) == 1
      assert hd(result.items).contact_id == "501"
    end

    test "returns normalized companies from search" do
      payload = fixture!("company_search.json")

      response = {:ok, %{status: 200, body: payload}}

      assert {:ok, result} = Response.handle_search_response(response, &Normalizer.company/1)
      assert length(result.items) == 1
      assert hd(result.items).company_id == "201"
    end

    test "returns normalized deals from search" do
      payload = fixture!("deal_search.json")

      response = {:ok, %{status: 200, body: payload}}

      assert {:ok, result} = Response.handle_search_response(response, &Normalizer.deal/1)
      assert length(result.items) == 1
      assert hd(result.items).deal_id == "301"
    end

    test "returns error on transport error" do
      response = {:error, :econnrefused}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :hubspot}} =
               Response.handle_search_response(response, &Normalizer.contact/1)
    end
  end

  defp fixture!(name) do
    Path.join([__DIR__, "..", "..", "..", "..", "test", "fixtures", "hubspot", name])
    |> Path.expand()
    |> File.read!()
    |> Jason.decode!()
  end
end
