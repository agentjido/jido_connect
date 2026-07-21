defmodule Jido.Connect.Intercom.Handlers.Actions.UntagContactTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Intercom.Handlers.Actions.UntagContact

  describe "run/2" do
    test "untags a contact with mock client" do
      input = %{tag_id: "tag-100", contact_ids: ["661240"]}

      runtime = %{
        credentials: %{intercom_client: Jido.Connect.Intercom.MockClient, api_key: "token"}
      }

      assert {:ok, tag} = UntagContact.run(input, runtime)
      assert tag.id == "tag-100"
    end

    test "returns validation error when tag_id is missing" do
      input = %{contact_ids: ["661240"]}

      runtime = %{
        credentials: %{intercom_client: Jido.Connect.Intercom.MockClient, api_key: "token"}
      }

      assert {:error, error} = UntagContact.run(input, runtime)
      assert error.reason == :invalid_tag_id
    end

    test "returns validation error when contact_ids is empty" do
      input = %{tag_id: "tag-100", contact_ids: []}

      runtime = %{
        credentials: %{intercom_client: Jido.Connect.Intercom.MockClient, api_key: "token"}
      }

      assert {:error, error} = UntagContact.run(input, runtime)
      assert error.reason == :invalid_contact_ids
    end

    test "returns error for auth failure" do
      input = %{tag_id: "tag-100", contact_ids: ["661240"]}

      runtime = %{
        credentials: %{
          intercom_client: Jido.Connect.Intercom.MockClient,
          api_key: "error_token"
        }
      }

      assert {:error, error} = UntagContact.run(input, runtime)
      assert error.status == 401
    end
  end
end
