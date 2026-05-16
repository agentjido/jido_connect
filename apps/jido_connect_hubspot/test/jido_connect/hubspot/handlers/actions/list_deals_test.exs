defmodule Jido.Connect.HubSpot.Handlers.Actions.ListDealsTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.HubSpot.Deal
  alias Jido.Connect.HubSpot.Handlers.Actions.ListDeals
  alias Jido.Connect.HubSpot.Pagination

  describe "run/2" do
    test "returns deals list with pagination" do
      deals = [
        Deal.new!(%{deal_id: "301", deal_name: "Acme Enterprise License"}),
        Deal.new!(%{deal_id: "302", deal_name: "Globex Support Contract"})
      ]

      pagination = Pagination.new!(%{after: "302", total: 8})
      MockClient.stub(list_deals: {:ok, %{items: deals, pagination: pagination}})
      credentials = %{hubspot_client: MockClient, api_key: "test-token"}

      assert {:ok, result} = ListDeals.run(%{}, %{credentials: credentials})
      assert length(result.deals) == 2
      assert hd(result.deals).deal_id == "301"
      assert result.pagination.after == "302"
    end
  end
end
