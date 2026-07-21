defmodule Jido.Connect.Intercom.Handlers.Actions.ListConversationsTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Intercom.Handlers.Actions.ListConversations

  describe "run/2" do
    test "lists conversations with mock client" do
      input = %{}

      runtime = %{
        credentials: %{intercom_client: Jido.Connect.Intercom.MockClient, api_key: "token"}
      }

      assert {:ok, result} = ListConversations.run(input, runtime)
      assert length(result.items) == 2
      assert hd(result.items).id == "401"
      assert hd(result.items).state == "open"
      assert hd(result.items).title == "Need help with API integration"
      assert result.pagination != nil
    end

    test "passes pagination params" do
      input = %{per_page: 1}

      runtime = %{
        credentials: %{intercom_client: Jido.Connect.Intercom.MockClient, api_key: "token"}
      }

      assert {:ok, result} = ListConversations.run(input, runtime)
      assert length(result.items) == 1
      assert result.pagination.next != nil
    end

    test "passes filter params" do
      input = %{open: true, assignee_id: "991"}

      runtime = %{
        credentials: %{intercom_client: Jido.Connect.Intercom.MockClient, api_key: "token"}
      }

      assert {:ok, result} = ListConversations.run(input, runtime)
      assert length(result.items) == 2
    end

    test "returns error for rate limit" do
      input = %{}

      runtime = %{
        credentials: %{
          intercom_client: Jido.Connect.Intercom.MockClient,
          api_key: "rate_limited_token"
        }
      }

      assert {:error, error} = ListConversations.run(input, runtime)
      assert error.status == 429
      assert error.reason == :rate_limited
    end
  end
end
