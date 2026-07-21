defmodule Jido.Connect.Intercom.Handlers.Actions.AddNoteTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Intercom.Handlers.Actions.AddNote

  describe "run/2" do
    test "adds a note to a conversation with mock client" do
      input = %{conversation_id: "401", body: "<p>Internal note</p>", admin_id: "991"}

      runtime = %{
        credentials: %{intercom_client: Jido.Connect.Intercom.MockClient, api_key: "token"}
      }

      assert {:ok, part} = AddNote.run(input, runtime)
      assert part.id == "part-200"
      assert part.part_type == "note"
    end

    test "returns validation error when conversation_id is missing" do
      input = %{body: "Note", admin_id: "991"}

      runtime = %{
        credentials: %{intercom_client: Jido.Connect.Intercom.MockClient, api_key: "token"}
      }

      assert {:error, error} = AddNote.run(input, runtime)
      assert error.reason == :invalid_conversation_id
    end

    test "returns validation error when body is missing" do
      input = %{conversation_id: "401", admin_id: "991"}

      runtime = %{
        credentials: %{intercom_client: Jido.Connect.Intercom.MockClient, api_key: "token"}
      }

      assert {:error, error} = AddNote.run(input, runtime)
      assert error.reason == :invalid_body
    end

    test "returns validation error when admin_id is missing" do
      input = %{conversation_id: "401", body: "Note"}

      runtime = %{
        credentials: %{intercom_client: Jido.Connect.Intercom.MockClient, api_key: "token"}
      }

      assert {:error, error} = AddNote.run(input, runtime)
      assert error.reason == :invalid_admin_id
    end

    test "returns error for auth failure" do
      input = %{conversation_id: "401", body: "Note", admin_id: "991"}

      runtime = %{
        credentials: %{
          intercom_client: Jido.Connect.Intercom.MockClient,
          api_key: "error_token"
        }
      }

      assert {:error, error} = AddNote.run(input, runtime)
      assert error.status == 401
    end
  end
end
