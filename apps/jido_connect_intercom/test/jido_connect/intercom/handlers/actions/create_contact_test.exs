defmodule Jido.Connect.Intercom.Handlers.Actions.CreateContactTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Intercom.Handlers.Actions.CreateContact

  describe "run/2" do
    test "creates a contact with mock client" do
      input = %{email: "new@example.com", name: "New User"}

      runtime = %{
        credentials: %{intercom_client: Jido.Connect.Intercom.MockClient, api_key: "token"}
      }

      assert {:ok, contact} = CreateContact.run(input, runtime)
      assert contact.id == "661300"
      assert contact.email == "new@example.com"
    end

    test "creates a contact with name only" do
      input = %{name: "Just Name"}

      runtime = %{
        credentials: %{intercom_client: Jido.Connect.Intercom.MockClient, api_key: "token"}
      }

      assert {:ok, contact} = CreateContact.run(input, runtime)
      assert contact.id == "661301"
    end

    test "returns validation error when no identifying fields" do
      input = %{}

      runtime = %{
        credentials: %{intercom_client: Jido.Connect.Intercom.MockClient, api_key: "token"}
      }

      assert {:error, error} = CreateContact.run(input, runtime)
      assert error.reason == :invalid_contact_attrs
    end

    test "returns error for auth failure" do
      input = %{email: "test@example.com"}

      runtime = %{
        credentials: %{
          intercom_client: Jido.Connect.Intercom.MockClient,
          api_key: "error_token"
        }
      }

      assert {:error, error} = CreateContact.run(input, runtime)
      assert error.status == 401
      assert error.reason == :unauthorized
    end
  end
end
