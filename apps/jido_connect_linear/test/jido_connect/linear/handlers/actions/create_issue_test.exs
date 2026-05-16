defmodule Jido.Connect.Linear.Handlers.Actions.CreateIssueTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Linear.Handlers.Actions.CreateIssue

  describe "run/2" do
    test "creates an issue with mock client" do
      input = %{team_id: "team-1", title: "New issue"}
      runtime = %{credentials: %{linear_client: Jido.Connect.Linear.MockClient, api_key: "token"}}

      assert {:ok, issue} = CreateIssue.run(input, runtime)
      assert issue.identifier == "LIN-124"
      assert issue.title == "New issue"
    end
  end
end
