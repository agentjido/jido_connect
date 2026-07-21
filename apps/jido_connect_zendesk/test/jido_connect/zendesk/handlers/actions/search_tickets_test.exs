defmodule Jido.Connect.Zendesk.Handlers.Actions.SearchTicketsTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Zendesk.Handlers.Actions.SearchTickets

  describe "run/2" do
    test "searches tickets with query using mock client" do
      input = %{query: "status:open priority:high"}

      runtime = %{
        credentials: %{zendesk_client: Jido.Connect.Zendesk.MockClient, api_key: "token"}
      }

      assert {:ok, result} = SearchTickets.run(input, runtime)
      assert length(result.items) == 1
      assert hd(result.items).id == 12345
      assert hd(result.items).subject == "Cannot reset password"
      assert result.count == 1
    end

    test "returns empty results for non-matching query" do
      input = %{query: "nonexistent"}

      runtime = %{
        credentials: %{zendesk_client: Jido.Connect.Zendesk.MockClient, api_key: "token"}
      }

      assert {:ok, result} = SearchTickets.run(input, runtime)
      assert result.items == []
      assert result.count == 0
    end

    test "passes pagination and sorting opts" do
      input = %{
        query: "status:open priority:high",
        page: 1,
        per_page: 10,
        sort_by: "created_at",
        sort_order: "desc"
      }

      runtime = %{
        credentials: %{zendesk_client: Jido.Connect.Zendesk.MockClient, api_key: "token"}
      }

      assert {:ok, result} = SearchTickets.run(input, runtime)
      assert result.items != []
    end
  end
end
