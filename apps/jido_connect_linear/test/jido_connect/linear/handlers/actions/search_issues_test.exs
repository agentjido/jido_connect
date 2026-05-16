defmodule Jido.Connect.Linear.Handlers.Actions.SearchIssuesTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Linear.Handlers.Actions.SearchIssues

  describe "run/2" do
    test "searches issues with filter using mock client" do
      input = %{filter: %{}}
      runtime = %{credentials: %{linear_client: Jido.Connect.Linear.MockClient, api_key: "token"}}

      assert {:ok, result} = SearchIssues.run(input, runtime)
      assert length(result.issues) == 1
      assert hd(result.issues).identifier == "LIN-123"
      assert result.total_count == 1
      assert result.has_next_page == false
    end

    test "passes pagination opts" do
      input = %{
        filter: %{},
        first: 25,
        after: nil,
        order_by: "createdAt"
      }

      runtime = %{credentials: %{linear_client: Jido.Connect.Linear.MockClient, api_key: "token"}}

      assert {:ok, result} = SearchIssues.run(input, runtime)
      assert result.issues != []
    end
  end
end
