defmodule Jido.Connect.Asana.Handlers.Actions.ListUsersTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Asana.Handlers.Actions.ListUsers

  describe "run/2" do
    test "lists users with mock client" do
      input = %{}

      runtime = %{
        credentials: %{asana_client: Jido.Connect.Asana.MockClient, api_key: "token"}
      }

      assert {:ok, result} = ListUsers.run(input, runtime)
      assert length(result.items) == 2
      assert hd(result.items).gid == "123456"
      assert hd(result.items).name == "Alice Nakamura"
      assert hd(result.items).email == "alice@example.com"
    end

    test "filters users by workspace" do
      input = %{workspace: "112233"}

      runtime = %{
        credentials: %{asana_client: Jido.Connect.Asana.MockClient, api_key: "token"}
      }

      assert {:ok, result} = ListUsers.run(input, runtime)
      assert length(result.items) == 1
    end

    test "returns error for auth failure" do
      input = %{}

      runtime = %{
        credentials: %{
          asana_client: Jido.Connect.Asana.MockClient,
          api_key: "error_token"
        }
      }

      assert {:error, error} = ListUsers.run(input, runtime)
      assert error.status == 401
      assert error.reason == :unauthorized
    end
  end
end
