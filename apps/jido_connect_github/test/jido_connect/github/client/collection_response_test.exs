defmodule Jido.Connect.GitHub.Client.CollectionResponseTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Error
  alias Jido.Connect.GitHub.Client.Response

  test "rejects invalid success bodies for account collection reads" do
    assert_invalid(Response.handle_user_response(ok([])))
    assert_invalid(Response.handle_user_installation_list_response(ok(%{})))
    assert_invalid(Response.handle_rate_limit_response(ok(%{})))
    assert_invalid(Response.handle_user_repository_list_response(ok(%{})))
  end

  test "rejects invalid success bodies for pull request and check evidence" do
    assert_invalid(Response.handle_pull_request_review_list_response(ok(%{})))
    assert_invalid(Response.handle_pull_request_requested_reviewer_response(ok(%{})))
    assert_invalid(Response.handle_check_run_list_response(ok(%{})))
  end

  test "rejects invalid success bodies for commit, tree, and blob reads" do
    assert_invalid(Response.handle_commit_response(ok([])))
    assert_invalid(Response.handle_git_tree_response(ok(%{})))
    assert_invalid(Response.handle_git_blob_response(ok(%{})))
  end

  test "maps failed collection responses through the safe provider error path" do
    for callback <- [
          &Response.handle_user_response/1,
          &Response.handle_user_installation_list_response/1,
          &Response.handle_rate_limit_response/1,
          &Response.handle_user_repository_list_response/1,
          &Response.handle_pull_request_review_list_response/1,
          &Response.handle_pull_request_requested_reviewer_response/1,
          &Response.handle_check_run_list_response/1,
          &Response.handle_commit_response/1,
          &Response.handle_git_tree_response/1,
          &Response.handle_git_blob_response/1
        ] do
      assert {:error, %Error.ProviderError{status: 503} = error} =
               callback.(
                 {:ok,
                  %{
                    status: 503,
                    body: %{
                      "message" => "unavailable",
                      "private" => "private-remote-response"
                    },
                    headers: %{}
                  }}
               )

      refute Map.has_key?(error.details, :body)
      refute inspect(error) =~ "private-remote-response"
    end
  end

  test "invalid success errors do not retain the remote body" do
    assert {:error, %Error.ProviderError{} = error} =
             Response.handle_git_blob_response(ok(%{"secret" => "private-remote-response"}))

    refute Map.has_key?(error.details, :body)
    refute inspect(error) =~ "private-remote-response"
  end

  defp ok(body), do: {:ok, %{status: 200, body: body, headers: %{}}}

  defp assert_invalid({:error, %Error.ProviderError{reason: :invalid_response}}), do: :ok
end
