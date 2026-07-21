defmodule Jido.Connect.Intercom.Handlers.Actions.TagContactTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Intercom.Handlers.Actions.TagContact

  describe "run/2" do
    test "tags a contact with mock client" do
      input = %{name: "vip", contact_ids: ["661240"]}

      runtime = %{
        credentials: %{intercom_client: Jido.Connect.Intercom.MockClient, api_key: "token"}
      }

      assert {:ok, tag} = TagContact.run(input, runtime)
      assert tag.id == "tag-100"
      assert tag.name == "vip"
      assert tag.type == "tag"
    end

    test "returns validation error when name is missing" do
      input = %{contact_ids: ["661240"]}

      runtime = %{
        credentials: %{intercom_client: Jido.Connect.Intercom.MockClient, api_key: "token"}
      }

      assert {:error, error} = TagContact.run(input, runtime)
      assert error.reason == :invalid_tag_name
    end

    test "returns validation error when contact_ids is empty" do
      input = %{name: "vip", contact_ids: []}

      runtime = %{
        credentials: %{intercom_client: Jido.Connect.Intercom.MockClient, api_key: "token"}
      }

      assert {:error, error} = TagContact.run(input, runtime)
      assert error.reason == :invalid_contact_ids
    end

    test "returns error for auth failure" do
      input = %{name: "vip", contact_ids: ["661240"]}

      runtime = %{
        credentials: %{
          intercom_client: Jido.Connect.Intercom.MockClient,
          api_key: "error_token"
        }
      }

      assert {:error, error} = TagContact.run(input, runtime)
      assert error.status == 401
    end
  end
end
