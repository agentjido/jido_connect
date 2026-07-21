defmodule Jido.Connect.Intercom.Handlers.Actions.ReplyConversationTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Intercom.Handlers.Actions.ReplyConversation

  describe "run/2" do
    test "replies to a conversation with mock client" do
      input = %{conversation_id: "401", body: "<p>Reply text</p>", admin_id: "991"}

      runtime = %{
        credentials: %{intercom_client: Jido.Connect.Intercom.MockClient, api_key: "token"}
      }

      assert {:ok, part} = ReplyConversation.run(input, runtime)
      assert part.id == "part-100"
      assert part.part_type == "comment"
    end

    test "returns validation error when conversation_id is missing" do
      input = %{body: "Reply"}

      runtime = %{
        credentials: %{intercom_client: Jido.Connect.Intercom.MockClient, api_key: "token"}
      }

      assert {:error, error} = ReplyConversation.run(input, runtime)
      assert error.reason == :invalid_conversation_id
    end

    test "returns validation error when body is missing" do
      input = %{conversation_id: "401"}

      runtime = %{
        credentials: %{intercom_client: Jido.Connect.Intercom.MockClient, api_key: "token"}
      }

      assert {:error, error} = ReplyConversation.run(input, runtime)
      assert error.reason == :invalid_body
    end

    test "returns error for auth failure" do
      input = %{conversation_id: "401", body: "Reply"}

      runtime = %{
        credentials: %{
          intercom_client: Jido.Connect.Intercom.MockClient,
          api_key: "error_token"
        }
      }

      assert {:error, error} = ReplyConversation.run(input, runtime)
      assert error.status == 401
    end
  end
end
