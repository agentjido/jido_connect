defmodule Jido.Connect.HubSpot.Handlers.Actions.SearchCompaniesTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.HubSpot.Company
  alias Jido.Connect.HubSpot.Handlers.Actions.SearchCompanies

  describe "run/2" do
    test "returns search results" do
      companies = [Company.new!(%{company_id: "201", name: "Acme Corp"})]
      MockClient.stub(search_companies: {:ok, %{items: companies}})
      credentials = %{hubspot_client: MockClient, api_key: "test-token"}

      assert {:ok, result} =
               SearchCompanies.run(%{query: "Acme"}, %{credentials: credentials})

      assert length(result.companies) == 1
      assert hd(result.companies).company_id == "201"
    end
  end
end
