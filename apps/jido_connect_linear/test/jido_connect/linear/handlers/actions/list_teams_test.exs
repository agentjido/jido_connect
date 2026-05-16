defmodule Jido.Connect.Linear.Handlers.Actions.ListTeamsTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Linear.Handlers.Actions.ListTeams

  describe "run/2" do
    test "lists teams with mock client" do
      input = %{}
      runtime = %{credentials: %{linear_client: Jido.Connect.Linear.MockClient, api_key: "token"}}

      assert {:ok, result} = ListTeams.run(input, runtime)
      assert length(result.teams) == 2
      assert hd(result.teams).key == "LIN"
      assert hd(result.teams).name == "Linear Team"
      assert result.has_next_page == false
    end
  end
end
