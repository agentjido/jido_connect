defmodule Jido.Connect.GitHub.ScopeResolver do
  @moduledoc false

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

  defp operation_id(%{action_id: action_id}), do: action_id
  defp operation_id(%{trigger_id: trigger_id}), do: trigger_id
  defp operation_id(%{id: id}), do: id
end
