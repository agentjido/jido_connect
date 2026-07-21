defmodule Jido.Connect.HubSpot.Handlers.Actions.CreateDealTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.HubSpot.Deal
  alias Jido.Connect.HubSpot.Handlers.Actions.CreateDeal

  describe "run/2" do
    test "returns deal on success" do
      deal = Deal.new!(%{deal_id: "301", deal_name: "New Deal"})
      MockClient.stub(create_deal: {:ok, deal})
      credentials = %{hubspot_client: MockClient, api_key: "test-token"}

      assert {:ok, %{deal: result}} =
               CreateDeal.run(%{deal_name: "New Deal"}, %{credentials: credentials})

      assert result.deal_id == "301"
      assert result.deal_name == "New Deal"
    end

    test "returns error when client fails" do
      error =
        {:error, %Jido.Connect.Error.ProviderError{provider: :hubspot, message: "Bad request"}}

      MockClient.stub(create_deal: error)
      credentials = %{hubspot_client: MockClient, api_key: "test-token"}

      assert {:error, %Jido.Connect.Error.ProviderError{}} =
               CreateDeal.run(%{deal_name: ""}, %{credentials: credentials})
    end
  end
end
