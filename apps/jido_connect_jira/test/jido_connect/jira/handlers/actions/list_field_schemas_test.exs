defmodule Jido.Connect.Jira.Handlers.Actions.ListFieldSchemasTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Jira.Handlers.Actions.ListFieldSchemas

  describe "run/2" do
    test "lists field schemas using mock client" do
      input = %{}
      runtime = %{credentials: %{jira_client: Jido.Connect.Jira.MockClient, api_key: "token"}}

      assert {:ok, result} = ListFieldSchemas.run(input, runtime)
      assert length(result.fields) == 3
      assert result.total == 3
      assert hd(result.fields).id == "summary"
    end

    test "passes expand option" do
      input = %{expand: "schema"}
      runtime = %{credentials: %{jira_client: Jido.Connect.Jira.MockClient, api_key: "token"}}

      assert {:ok, result} = ListFieldSchemas.run(input, runtime)
      assert result.fields != []
    end
  end
end
