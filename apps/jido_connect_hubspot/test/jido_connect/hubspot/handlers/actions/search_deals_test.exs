defmodule Jido.Connect.HubSpot.Handlers.Actions.SearchDealsTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.HubSpot.Deal
  alias Jido.Connect.HubSpot.Handlers.Actions.SearchDeals

  describe "run/2" do
    test "returns search results" do
      deals = [Deal.new!(%{deal_id: "301", deal_name: "Acme Enterprise License"})]
      MockClient.stub(search_deals: {:ok, %{items: deals}})
      credentials = %{hubspot_client: MockClient, api_key: "test-token"}

      assert {:ok, result} =
               SearchDeals.run(%{query: "Enterprise"}, %{credentials: credentials})

      assert length(result.deals) == 1
      assert hd(result.deals).deal_id == "301"
    end
  end
end
