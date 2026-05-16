defmodule Jido.Connect.Jira.Handlers.Actions.AddCommentTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Jira.Handlers.Actions.AddComment

  describe "run/2" do
    test "adds a comment with mock client" do
      input = %{issue_key: "PROJ-123", body: "This is a test comment."}
      runtime = %{credentials: %{jira_client: Jido.Connect.Jira.MockClient, api_key: "token"}}

      assert {:ok, comment} = AddComment.run(input, runtime)
      assert comment.id == "20010"
      assert comment.body == "Test comment body"
      assert comment.created_at == "2026-05-15T14:00:00.000+0000"
    end

    test "returns error when body is missing" do
      input = %{issue_key: "PROJ-123"}
      runtime = %{credentials: %{jira_client: Jido.Connect.Jira.MockClient, api_key: "token"}}

      assert {:error, error} = AddComment.run(input, runtime)
      assert error.reason == :invalid_comment_body
    end

    test "returns error when body is empty" do
      input = %{issue_key: "PROJ-123", body: ""}
      runtime = %{credentials: %{jira_client: Jido.Connect.Jira.MockClient, api_key: "token"}}

      assert {:error, error} = AddComment.run(input, runtime)
      assert error.reason == :invalid_comment_body
    end
  end
end
