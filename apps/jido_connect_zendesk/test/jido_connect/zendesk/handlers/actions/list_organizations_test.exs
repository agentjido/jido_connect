defmodule Jido.Connect.Zendesk.Handlers.Actions.ListOrganizationsTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Zendesk.Handlers.Actions.ListOrganizations

  describe "run/2" do
    test "lists organizations with mock client" do
      input = %{}

      runtime = %{
        credentials: %{zendesk_client: Jido.Connect.Zendesk.MockClient, api_key: "token"}
      }

      assert {:ok, result} = ListOrganizations.run(input, runtime)
      assert length(result.items) == 1
      assert hd(result.items).id == 201
      assert hd(result.items).name == "Acme Corp"
      assert hd(result.items).domain_names == ["acme.com"]
      assert hd(result.items).tags == ["enterprise", "vip"]
      assert result.count == 1
    end

    test "passes pagination params" do
      input = %{page: 2, per_page: 10}

      runtime = %{
        credentials: %{zendesk_client: Jido.Connect.Zendesk.MockClient, api_key: "token"}
      }

      assert {:ok, result} = ListOrganizations.run(input, runtime)
      assert result.items == []
    end
  end
end
