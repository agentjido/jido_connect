defmodule Jido.Connect.Asana.Handlers.Actions.ListProjectsTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Asana.Handlers.Actions.ListProjects

  describe "run/2" do
    test "lists projects with mock client" do
      input = %{}

      runtime = %{
        credentials: %{asana_client: Jido.Connect.Asana.MockClient, api_key: "token"}
      }

      assert {:ok, result} = ListProjects.run(input, runtime)
      assert length(result.items) == 2
      assert hd(result.items).gid == "445566"
      assert hd(result.items).name == "Website Redesign"
    end

    test "filters projects by workspace" do
      input = %{workspace: "112233"}

      runtime = %{
        credentials: %{asana_client: Jido.Connect.Asana.MockClient, api_key: "token"}
      }

      assert {:ok, result} = ListProjects.run(input, runtime)
      assert length(result.items) == 1
      assert hd(result.items).name == "Website Redesign"
    end

    test "returns error for auth failure" do
      input = %{}

      runtime = %{
        credentials: %{
          asana_client: Jido.Connect.Asana.MockClient,
          api_key: "error_token"
        }
      }

      assert {:error, error} = ListProjects.run(input, runtime)
      assert error.status == 401
      assert error.reason == :unauthorized
    end
  end
end
