defmodule Jido.Connect.Linear.Handlers.Actions.GetTeamTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Linear.Handlers.Actions.GetTeam

  describe "run/2" do
    test "fetches a team by ID with mock client" do
      input = %{team_id: "team-1"}
      runtime = %{credentials: %{linear_client: Jido.Connect.Linear.MockClient, api_key: "token"}}

      assert {:ok, team} = GetTeam.run(input, runtime)
      assert team.id == "team-1"
      assert team.key == "LIN"
      assert team.name == "Linear Team"
      assert team.description == "Core Linear product team."
      assert team.icon == "🚀"
      assert team.color == "#5B5DEF"
      assert team.lead.name == "Alice Nakamura"
    end
  end
end
