defmodule Jido.Connect.Intercom.Handlers.Actions.ListContactsTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Intercom.Handlers.Actions.ListContacts

  describe "run/2" do
    test "lists contacts with mock client" do
      input = %{}

      runtime = %{
        credentials: %{intercom_client: Jido.Connect.Intercom.MockClient, api_key: "token"}
      }

      assert {:ok, result} = ListContacts.run(input, runtime)
      assert length(result.items) == 2
      assert hd(result.items).id == "661240"
      assert hd(result.items).name == "Alice Nakamura"
      assert hd(result.items).email == "alice@example.com"
      assert result.pagination != nil
      assert result.pagination.page == 1
    end

    test "passes pagination params" do
      input = %{per_page: 1}

      runtime = %{
        credentials: %{intercom_client: Jido.Connect.Intercom.MockClient, api_key: "token"}
      }

      assert {:ok, result} = ListContacts.run(input, runtime)
      assert length(result.items) == 1
      assert result.pagination.next != nil
    end

    test "returns error for auth failure" do
      input = %{}

      runtime = %{
        credentials: %{
          intercom_client: Jido.Connect.Intercom.MockClient,
          api_key: "error_token"
        }
      }

      assert {:error, error} = ListContacts.run(input, runtime)
      assert error.status == 401
      assert error.reason == :unauthorized
    end
  end
end
