defmodule Jido.Connect.Asana.Handlers.Actions.ListWorkspacesTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Asana.Handlers.Actions.ListWorkspaces

  describe "run/2" do
    test "lists workspaces with mock client" do
      input = %{}

      runtime = %{
        credentials: %{asana_client: Jido.Connect.Asana.MockClient, api_key: "token"}
      }

      assert {:ok, result} = ListWorkspaces.run(input, runtime)
      assert length(result.items) == 2
      assert hd(result.items).gid == "112233"
      assert hd(result.items).name == "Acme Corp"
      assert result.pagination != nil
    end

    test "passes pagination params" do
      input = %{limit: 1}

      runtime = %{
        credentials: %{asana_client: Jido.Connect.Asana.MockClient, api_key: "token"}
      }

      assert {:ok, result} = ListWorkspaces.run(input, runtime)
      assert length(result.items) == 1
      assert result.pagination.has_next == true
    end

    test "returns error for auth failure" do
      input = %{}

      runtime = %{
        credentials: %{
          asana_client: Jido.Connect.Asana.MockClient,
          api_key: "error_token"
        }
      }

      assert {:error, error} = ListWorkspaces.run(input, runtime)
      assert error.status == 401
      assert error.reason == :unauthorized
    end
  end
end
