defmodule Jido.Connect.Intercom.Handlers.Actions.ListTeamsTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Intercom.Handlers.Actions.ListTeams

  describe "run/2" do
    test "lists teams with mock client" do
      input = %{}

      runtime = %{
        credentials: %{intercom_client: Jido.Connect.Intercom.MockClient, api_key: "token"}
      }

      assert {:ok, result} = ListTeams.run(input, runtime)
      assert length(result.items) == 2
      assert hd(result.items).id == "team-100"
      assert hd(result.items).name == "Support"
      assert hd(result.items).admin_ids == ["991", "992"]
      assert result.pagination != nil
    end

    test "passes pagination params" do
      input = %{per_page: 10}

      runtime = %{
        credentials: %{intercom_client: Jido.Connect.Intercom.MockClient, api_key: "token"}
      }

      assert {:ok, result} = ListTeams.run(input, runtime)
      assert length(result.items) == 2
    end
  end
end
