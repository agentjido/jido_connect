defmodule Jido.Connect.Linear.Handlers.Actions.ListCommentsTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Linear.Handlers.Actions.ListComments

  describe "run/2" do
    test "lists comments for an issue with mock client" do
      input = %{issue_id: "uuid-001"}
      runtime = %{credentials: %{linear_client: Jido.Connect.Linear.MockClient, api_key: "token"}}

      assert {:ok, result} = ListComments.run(input, runtime)
      assert length(result.comments) == 2
      assert hd(result.comments).body == "Investigated the OAuth2 flow."
      assert hd(result.comments).author.name == "Alice Nakamura"
      assert result.has_next_page == false
      assert result.total_count == 2
    end

    test "passes pagination opts" do
      input = %{issue_id: "uuid-001", first: 10, after: "cursor-abc"}
      runtime = %{credentials: %{linear_client: Jido.Connect.Linear.MockClient, api_key: "token"}}

      assert {:ok, result} = ListComments.run(input, runtime)
      assert result.comments != []
    end
  end
end
