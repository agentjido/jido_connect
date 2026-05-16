defmodule Jido.Connect.Linear.Handlers.Actions.AddCommentTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Linear.Handlers.Actions.AddComment

  describe "run/2" do
    test "adds a comment with mock client" do
      input = %{issue_id: "LIN-123", body: "Test comment body"}
      runtime = %{credentials: %{linear_client: Jido.Connect.Linear.MockClient, api_key: "token"}}

      assert {:ok, comment} = AddComment.run(input, runtime)
      assert comment.id == "comment-1"
      assert comment.body == "Test comment body"
      assert comment.created_at == "2026-05-15T14:00:00.000Z"
    end
  end
end
