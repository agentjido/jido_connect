defmodule Jido.Connect.Intercom.Handlers.Actions.UpdateContactTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Intercom.Handlers.Actions.UpdateContact

  describe "run/2" do
    test "updates a contact with mock client" do
      input = %{contact_id: "661240", name: "Alice Updated"}

      runtime = %{
        credentials: %{intercom_client: Jido.Connect.Intercom.MockClient, api_key: "token"}
      }

      assert {:ok, contact} = UpdateContact.run(input, runtime)
      assert contact.id == "661240"
      assert contact.name == "Alice Updated"
    end

    test "returns validation error when contact_id is missing" do
      input = %{name: "No ID"}

      runtime = %{
        credentials: %{intercom_client: Jido.Connect.Intercom.MockClient, api_key: "token"}
      }

      assert {:error, error} = UpdateContact.run(input, runtime)
      assert error.reason == :invalid_contact_id
    end

    test "returns error for auth failure" do
      input = %{contact_id: "661240", name: "Updated"}

      runtime = %{
        credentials: %{
          intercom_client: Jido.Connect.Intercom.MockClient,
          api_key: "error_token"
        }
      }

      assert {:error, error} = UpdateContact.run(input, runtime)
      assert error.status == 401
    end
  end
end
