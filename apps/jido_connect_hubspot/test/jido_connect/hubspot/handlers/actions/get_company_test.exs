defmodule Jido.Connect.HubSpot.Handlers.Actions.GetCompanyTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.HubSpot.Company
  alias Jido.Connect.HubSpot.Handlers.Actions.GetCompany

  describe "run/2" do
    test "returns company on success" do
      company = Company.new!(%{company_id: "201", name: "Acme Corp", domain: "acme.example.com"})
      MockClient.stub(get_company: {:ok, company})
      credentials = %{hubspot_client: MockClient, api_key: "test-token"}

      assert {:ok, %{company: result}} =
               GetCompany.run(%{company_id: "201"}, %{credentials: credentials})

      assert result.company_id == "201"
      assert result.name == "Acme Corp"
    end

    test "returns error when client fails" do
      error =
        {:error, %Jido.Connect.Error.ProviderError{provider: :hubspot, message: "Not found"}}

      MockClient.stub(get_company: error)
      credentials = %{hubspot_client: MockClient, api_key: "test-token"}

      assert {:error, %Jido.Connect.Error.ProviderError{}} =
               GetCompany.run(%{company_id: "999"}, %{credentials: credentials})
    end
  end
end
