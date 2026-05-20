defmodule Jido.Connect.Asana.Handlers.Actions.GetUserTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Asana.Handlers.Actions.GetUser

  describe "run/2" do
    test "fetches a user by gid with mock client" do
      input = %{user_gid: "123456"}

      runtime = %{
        credentials: %{asana_client: Jido.Connect.Asana.MockClient, api_key: "token"}
      }

      assert {:ok, result} = GetUser.run(input, runtime)
      assert result.user.gid == "123456"
      assert result.user.name == "Alice Nakamura"
      assert result.user.email == "alice@example.com"
    end

    test "returns error for not-found user" do
      input = %{user_gid: "unknown"}

      runtime = %{
        credentials: %{asana_client: Jido.Connect.Asana.MockClient, api_key: "token"}
      }

      assert {:error, error} = GetUser.run(input, runtime)
      assert error.status == 404
      assert error.reason == :not_found
    end

    test "returns error for auth failure" do
      input = %{user_gid: "123456"}

      runtime = %{
        credentials: %{
          asana_client: Jido.Connect.Asana.MockClient,
          api_key: "error_token"
        }
      }

      assert {:error, error} = GetUser.run(input, runtime)
      assert error.status == 401
    end
  end
end
