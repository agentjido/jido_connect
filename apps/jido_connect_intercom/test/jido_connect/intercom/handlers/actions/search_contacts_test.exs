defmodule Jido.Connect.Intercom.Handlers.Actions.SearchContactsTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Intercom.Handlers.Actions.SearchContacts

  describe "run/2" do
    test "searches contacts with query using mock client" do
      input = %{query: "email:alice@example.com"}

      runtime = %{
        credentials: %{intercom_client: Jido.Connect.Intercom.MockClient, api_key: "token"}
      }

      assert {:ok, result} = SearchContacts.run(input, runtime)
      assert length(result.items) == 1
      assert hd(result.items).id == "661240"
      assert hd(result.items).email == "alice@example.com"
      assert result.total_count == 1
    end

    test "returns empty results for non-matching query" do
      input = %{query: "email:nonexistent@example.com"}

      runtime = %{
        credentials: %{intercom_client: Jido.Connect.Intercom.MockClient, api_key: "token"}
      }

      assert {:ok, result} = SearchContacts.run(input, runtime)
      assert result.items == []
      assert result.total_count == 0
    end

    test "passes pagination opts" do
      input = %{query: "email:alice@example.com", per_page: 10, starting_after: "abc"}

      runtime = %{
        credentials: %{intercom_client: Jido.Connect.Intercom.MockClient, api_key: "token"}
      }

      assert {:ok, result} = SearchContacts.run(input, runtime)
      assert result.items != []
    end
  end
end
