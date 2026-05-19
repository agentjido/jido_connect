defmodule Jido.Connect.Intercom.Handlers.Actions.SearchConversationsTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Intercom.Handlers.Actions.SearchConversations

  describe "run/2" do
    test "searches conversations with query using mock client" do
      input = %{query: "open:true"}

      runtime = %{
        credentials: %{intercom_client: Jido.Connect.Intercom.MockClient, api_key: "token"}
      }

      assert {:ok, result} = SearchConversations.run(input, runtime)
      assert length(result.items) == 1
      assert hd(result.items).id == "401"
      assert hd(result.items).state == "open"
      assert result.total_count == 1
    end

    test "returns empty results for non-matching query" do
      input = %{query: "closed:true"}

      runtime = %{
        credentials: %{intercom_client: Jido.Connect.Intercom.MockClient, api_key: "token"}
      }

      assert {:ok, result} = SearchConversations.run(input, runtime)
      assert result.items == []
      assert result.total_count == 0
    end

    test "passes pagination opts" do
      input = %{query: "open:true", per_page: 10, starting_after: "abc"}

      runtime = %{
        credentials: %{intercom_client: Jido.Connect.Intercom.MockClient, api_key: "token"}
      }

      assert {:ok, result} = SearchConversations.run(input, runtime)
      assert result.items != []
    end
  end
end
