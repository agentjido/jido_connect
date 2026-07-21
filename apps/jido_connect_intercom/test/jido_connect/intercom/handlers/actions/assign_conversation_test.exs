defmodule Jido.Connect.Intercom.Handlers.Actions.AssignConversationTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Intercom.Handlers.Actions.AssignConversation

  describe "run/2" do
    test "assigns a conversation to an admin with mock client" do
      input = %{conversation_id: "401", admin_id: "991"}

      runtime = %{
        credentials: %{intercom_client: Jido.Connect.Intercom.MockClient, api_key: "token"}
      }

      assert {:ok, part} = AssignConversation.run(input, runtime)
      assert part.id == "part-300"
      assert part.part_type == "assignment"
      assert part.assigned_to.type == "admin"
      assert part.assigned_to.id == "991"
    end

    test "assigns a conversation to a team with mock client" do
      input = %{conversation_id: "401", team_id: "team-100"}

      runtime = %{
        credentials: %{intercom_client: Jido.Connect.Intercom.MockClient, api_key: "token"}
      }

      assert {:ok, part} = AssignConversation.run(input, runtime)
      assert part.id == "part-301"
      assert part.part_type == "assignment"
      assert part.assigned_to.type == "team"
    end

    test "returns validation error when conversation_id is missing" do
      input = %{admin_id: "991"}

      runtime = %{
        credentials: %{intercom_client: Jido.Connect.Intercom.MockClient, api_key: "token"}
      }

      assert {:error, error} = AssignConversation.run(input, runtime)
      assert error.reason == :invalid_conversation_id
    end

    test "returns validation error when neither admin_id nor team_id" do
      input = %{conversation_id: "401"}

      runtime = %{
        credentials: %{intercom_client: Jido.Connect.Intercom.MockClient, api_key: "token"}
      }

      assert {:error, error} = AssignConversation.run(input, runtime)
      assert error.reason == :invalid_assignee
    end

    test "returns error for auth failure" do
      input = %{conversation_id: "401", admin_id: "991"}

      runtime = %{
        credentials: %{
          intercom_client: Jido.Connect.Intercom.MockClient,
          api_key: "error_token"
        }
      }

      assert {:error, error} = AssignConversation.run(input, runtime)
      assert error.status == 401
    end
  end
end
