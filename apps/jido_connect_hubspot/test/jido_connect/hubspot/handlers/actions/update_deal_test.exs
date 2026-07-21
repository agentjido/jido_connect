defmodule Jido.Connect.HubSpot.Handlers.Actions.UpdateDealTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.HubSpot.Deal
  alias Jido.Connect.HubSpot.Handlers.Actions.UpdateDeal

  describe "run/2" do
    test "returns updated deal on success" do
      deal = Deal.new!(%{deal_id: "301", deal_name: "Updated Deal"})
      MockClient.stub(update_deal: {:ok, deal})
      credentials = %{hubspot_client: MockClient, api_key: "test-token"}

      assert {:ok, %{deal: result}} =
               UpdateDeal.run(%{deal_id: "301", deal_name: "Updated Deal"}, %{
                 credentials: credentials
               })

      assert result.deal_id == "301"
      assert result.deal_name == "Updated Deal"
    end

    test "returns error when client fails" do
      error =
        {:error, %Jido.Connect.Error.ProviderError{provider: :hubspot, message: "Not found"}}

      MockClient.stub(update_deal: error)
      credentials = %{hubspot_client: MockClient, api_key: "test-token"}

      assert {:error, %Jido.Connect.Error.ProviderError{}} =
               UpdateDeal.run(%{deal_id: "999"}, %{credentials: credentials})
    end
  end
end
