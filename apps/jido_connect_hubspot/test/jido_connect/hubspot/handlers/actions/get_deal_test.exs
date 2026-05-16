defmodule Jido.Connect.HubSpot.Handlers.Actions.GetDealTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.HubSpot.Deal
  alias Jido.Connect.HubSpot.Handlers.Actions.GetDeal

  describe "run/2" do
    test "returns deal on success" do
      deal = Deal.new!(%{deal_id: "301", deal_name: "Acme Enterprise License", amount: 120_000})
      MockClient.stub(get_deal: {:ok, deal})
      credentials = %{hubspot_client: MockClient, api_key: "test-token"}

      assert {:ok, %{deal: result}} = GetDeal.run(%{deal_id: "301"}, %{credentials: credentials})
      assert result.deal_id == "301"
      assert result.deal_name == "Acme Enterprise License"
    end

    test "returns error when client fails" do
      error =
        {:error, %Jido.Connect.Error.ProviderError{provider: :hubspot, message: "Not found"}}

      MockClient.stub(get_deal: error)
      credentials = %{hubspot_client: MockClient, api_key: "test-token"}

      assert {:error, %Jido.Connect.Error.ProviderError{}} =
               GetDeal.run(%{deal_id: "999"}, %{credentials: credentials})
    end
  end
end
