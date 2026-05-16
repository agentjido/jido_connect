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

    test "includes confirmation metadata in result" do
      input = %{issue_id: "LIN-123", body: "Test comment body"}
      runtime = %{credentials: %{linear_client: Jido.Connect.Linear.MockClient, api_key: "token"}}

      assert {:ok, comment} = AddComment.run(input, runtime)
      assert comment._confirmation.action == :commented
      assert comment._confirmation.issue_id == "LIN-123"
    end

    test "returns error when issue_id is missing" do
      input = %{body: "Test comment body"}
      runtime = %{credentials: %{linear_client: Jido.Connect.Linear.MockClient, api_key: "token"}}

      assert {:error, error} = AddComment.run(input, runtime)
      assert error.reason == :invalid_issue_id
    end

    test "returns error when body is missing" do
      input = %{issue_id: "LIN-123"}
      runtime = %{credentials: %{linear_client: Jido.Connect.Linear.MockClient, api_key: "token"}}

      assert {:error, error} = AddComment.run(input, runtime)
      assert error.reason == :invalid_comment_body
    end

    test "returns error when body is empty" do
      input = %{issue_id: "LIN-123", body: ""}
      runtime = %{credentials: %{linear_client: Jido.Connect.Linear.MockClient, api_key: "token"}}

      assert {:error, error} = AddComment.run(input, runtime)
      assert error.reason == :invalid_comment_body
    end
  end
end
