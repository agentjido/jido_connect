defmodule Jido.Connect.Zendesk.Handlers.Actions.ListUsersTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Zendesk.Handlers.Actions.ListUsers

  describe "run/2" do
    test "lists users with mock client" do
      input = %{}

      runtime = %{
        credentials: %{zendesk_client: Jido.Connect.Zendesk.MockClient, api_key: "token"}
      }

      assert {:ok, result} = ListUsers.run(input, runtime)
      assert length(result.items) == 2
      assert hd(result.items).id == 9001
      assert hd(result.items).name == "Alice Nakamura"
      assert hd(result.items).role == "agent"
    end

    test "filters by role" do
      input = %{role: "agent"}

      runtime = %{
        credentials: %{zendesk_client: Jido.Connect.Zendesk.MockClient, api_key: "token"}
      }

      assert {:ok, result} = ListUsers.run(input, runtime)
      assert length(result.items) == 1
      assert hd(result.items).role == "agent"
    end

    test "passes pagination params" do
      input = %{page: 1, per_page: 50}

      runtime = %{
        credentials: %{zendesk_client: Jido.Connect.Zendesk.MockClient, api_key: "token"}
      }

      assert {:ok, result} = ListUsers.run(input, runtime)
      assert result.items != []
    end
  end
end
