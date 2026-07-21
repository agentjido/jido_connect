defmodule Jido.Connect.Intercom.Handlers.Actions.GetContactTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Intercom.Handlers.Actions.GetContact

  describe "run/2" do
    test "fetches a contact by id with mock client" do
      input = %{contact_id: "661240"}

      runtime = %{
        credentials: %{intercom_client: Jido.Connect.Intercom.MockClient, api_key: "token"}
      }

      assert {:ok, contact} = GetContact.run(input, runtime)
      assert contact.id == "661240"
      assert contact.name == "Alice Nakamura"
      assert contact.email == "alice@example.com"
      assert contact.role == "user"
    end

    test "returns error for not-found contact" do
      input = %{contact_id: "unknown"}

      runtime = %{
        credentials: %{intercom_client: Jido.Connect.Intercom.MockClient, api_key: "token"}
      }

      assert {:error, error} = GetContact.run(input, runtime)
      assert error.status == 404
    end
  end
end
