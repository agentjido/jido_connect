defmodule Jido.Connect.HubSpot.Handlers.Actions.ListCompaniesTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.HubSpot.Company
  alias Jido.Connect.HubSpot.Handlers.Actions.ListCompanies
  alias Jido.Connect.HubSpot.Pagination

  describe "run/2" do
    test "returns companies list with pagination" do
      companies = [
        Company.new!(%{company_id: "201", name: "Acme Corp"}),
        Company.new!(%{company_id: "202", name: "Globex Inc"})
      ]

      pagination = Pagination.new!(%{after: "202", total: 15})
      MockClient.stub(list_companies: {:ok, %{items: companies, pagination: pagination}})
      credentials = %{hubspot_client: MockClient, api_key: "test-token"}

      assert {:ok, result} = ListCompanies.run(%{}, %{credentials: credentials})
      assert length(result.companies) == 2
      assert hd(result.companies).company_id == "201"
      assert result.pagination.after == "202"
    end
  end
end
