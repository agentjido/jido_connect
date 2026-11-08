defmodule Jido.Connect.GitHub.ScopeResolver do
  @moduledoc false

  alias Jido.Connect.Data

  def required_scopes(operation, input, %{profile: :user, metadata: metadata}) do
    if Data.get(metadata, "token_kind") in [:github_app_user, "github_app_user"] do
      github_app_user_scopes(operation_id(operation), input, metadata)
    else
      Map.get(operation, :scopes, [])
    end
  end

  def required_scopes(operation, _input, %{profile: :installation}) do
    case operation_id(operation) do
      "github.repo.list" -> ["metadata:read"]
      "github.repo.get" -> ["metadata:read"]
      "github.branch.list" -> ["metadata:read", "contents:read"]
      "github.ref.compare" -> ["metadata:read", "contents:read"]
      "github.file.read" -> ["metadata:read", "contents:read"]
      "github.file.update" -> ["metadata:read", "contents:write"]
      "github.issue_comment.create" -> ["metadata:read", "issues:write"]
      "github.issue_comment.list" -> ["metadata:read", "issues:read"]
      "github.issue.assign" -> ["metadata:read", "issues:write"]
      "github.issue.label.add" -> ["metadata:read", "issues:write"]
      "github.issue.label.remove" -> ["metadata:read", "issues:write"]
      "github.issue.create" -> ["metadata:read", "issues:write"]
      "github.issue.list" -> ["metadata:read", "issues:read"]
      "github.release.create" -> ["metadata:read", "contents:write"]
      "github.release_asset.upload" -> ["metadata:read", "contents:write"]
      "github.release.list" -> ["metadata:read", "contents:read"]
      "github.workflow_run.job.list" -> ["metadata:read", "actions:read"]
      "github.workflow_run.list" -> ["metadata:read", "actions:read"]
      "github.workflow_run.updated" -> ["metadata:read", "actions:read"]
      "github.workflow_run.rerun" -> ["metadata:read", "actions:write"]
      "github.workflow_run.cancel" -> ["metadata:read", "actions:write"]
      "github.workflow.dispatch" -> ["metadata:read", "actions:write"]
      "github.pull_request.create" -> ["metadata:read", "pull_requests:write"]
      "github.pull_request.merge" -> ["metadata:read", "pull_requests:write", "contents:write"]
      "github.pull_request.review_comment.create" -> ["metadata:read", "pull_requests:write"]
      "github.pull_request.reviewers.request" -> ["metadata:read", "pull_requests:write"]
      "github.pull_request.update" -> ["metadata:read", "pull_requests:write"]
      "github.pull_request.list" -> ["metadata:read", "pull_requests:read"]
      "github.pull_request_file.list" -> ["metadata:read", "pull_requests:read"]
      "github.issue.new" -> ["metadata:read", "issues:read"]
      "github.pull_request.updated" -> ["metadata:read", "pull_requests:read"]
      _other -> Map.get(operation, :scopes, [])
    end
  end

  def required_scopes(operation, _input, _connection), do: Map.get(operation, :scopes, [])

  defp github_app_user_scopes(action_id, _input, _metadata)
       when action_id in [
              "github.user.get",
              "github.user_installation.list",
              "github.rate_limit.get"
            ],
       do: []

  defp github_app_user_scopes(action_id, _input, metadata)
       when action_id in [
              "github.repo.search",
              "github.repo.get",
              "github.issue.list",
              "github.pull_request.list",
              "github.pull_request.get",
              "github.pull_request_review.list",
              "github.pull_request_requested_reviewer.list",
              "github.check_run.list",
              "github.workflow_run.list",
              "github.commit.get",
              "github.git_tree.get",
              "github.git_blob.get"
            ] do
    if Data.get(metadata, "public_read", false),
      do: ["public:read"],
      else: installed_scopes(action_id)
  end

  defp github_app_user_scopes(action_id, _input, _metadata)
       when action_id in [
              "github.user_installation_repository.list",
              "github.installation_repository.list",
              "github.repo.list"
            ],
       do: ["metadata:read"]

  defp github_app_user_scopes(_action_id, _input, _metadata), do: ["github_app_user:unsupported"]

  defp installed_scopes(action_id) when action_id in ["github.repo.search", "github.repo.get"],
    do: ["metadata:read"]

  defp installed_scopes("github.issue.list"), do: ["metadata:read", "issues:read"]

  defp installed_scopes(action_id)
       when action_id in [
              "github.pull_request.list",
              "github.pull_request.get",
              "github.pull_request_review.list",
              "github.pull_request_requested_reviewer.list"
            ],
       do: ["metadata:read", "pull_requests:read"]

  defp installed_scopes("github.check_run.list"), do: ["metadata:read", "checks:read"]
  defp installed_scopes("github.workflow_run.list"), do: ["metadata:read", "actions:read"]

  defp installed_scopes(action_id)
       when action_id in ["github.commit.get", "github.git_tree.get", "github.git_blob.get"],
       do: ["metadata:read", "contents:read"]

  defp operation_id(%{action_id: action_id}), do: action_id
  defp operation_id(%{trigger_id: trigger_id}), do: trigger_id
  defp operation_id(%{id: id}), do: id
end
