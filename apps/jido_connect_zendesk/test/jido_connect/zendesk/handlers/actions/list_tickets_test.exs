defmodule Jido.Connect.Zendesk.Handlers.Actions.ListTicketsTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Zendesk.Handlers.Actions.ListTickets

  describe "run/2" do
    test "lists tickets with mock client" do
      input = %{}

      runtime = %{
        credentials: %{zendesk_client: Jido.Connect.Zendesk.MockClient, api_key: "token"}
      }

      assert {:ok, result} = ListTickets.run(input, runtime)
      assert length(result.items) == 2
      assert hd(result.items).id == 12345
      assert hd(result.items).subject == "Cannot reset password"
      assert result.count == 2
      assert result.next_page =~ "page=2"
    end

    test "passes pagination params" do
      input = %{page: 2, per_page: 25}

      runtime = %{
        credentials: %{zendesk_client: Jido.Connect.Zendesk.MockClient, api_key: "token"}
      }

      assert {:ok, result} = ListTickets.run(input, runtime)
      assert result.items == []
      assert result.count == 0
      assert result.next_page == nil
    end

    test "passes sorting params" do
      input = %{sort_by: "updated_at", sort_order: "desc"}

      runtime = %{
        credentials: %{zendesk_client: Jido.Connect.Zendesk.MockClient, api_key: "token"}
      }

      assert {:ok, result} = ListTickets.run(input, runtime)
      assert length(result.items) == 2
    end
  end
end
