defmodule Jido.Connect.Intercom.Handlers.Actions.GetConversationTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Intercom.Handlers.Actions.GetConversation

  describe "run/2" do
    test "fetches a conversation by id with mock client" do
      input = %{conversation_id: "401"}

      runtime = %{
        credentials: %{intercom_client: Jido.Connect.Intercom.MockClient, api_key: "token"}
      }

      assert {:ok, conv} = GetConversation.run(input, runtime)
      assert conv.id == "401"
      assert conv.state == "open"
      assert conv.open == true
      assert conv.title == "Need help with API integration"
      assert conv.priority == "not_priority"
    end

    test "returns error for not-found conversation" do
      input = %{conversation_id: "unknown"}

      runtime = %{
        credentials: %{intercom_client: Jido.Connect.Intercom.MockClient, api_key: "token"}
      }

      assert {:error, error} = GetConversation.run(input, runtime)
      assert error.status == 404
    end
  end
end
