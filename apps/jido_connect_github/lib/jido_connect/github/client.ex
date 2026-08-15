defmodule Jido.Connect.GitHub.Client do
  @moduledoc """
  Compatibility facade for the GitHub REST client.

  New code should prefer the API-area modules under `Jido.Connect.GitHub.Client.*`
  when it wants a narrower dependency surface. Existing handlers and host apps
  can keep calling this module.
  """

  alias Jido.Connect.GitHub.Client

  defdelegate list_repositories(params, access_token), to: Client.Repositories
  defdelegate get_repository(owner, name, access_token), to: Client.Repositories
  defdelegate list_branches(params, access_token), to: Client.Repositories
  defdelegate create_branch(repo, attrs, access_token), to: Client.Repositories
  defdelegate list_commits(params, access_token), to: Client.Repositories
  defdelegate compare_refs(params, access_token), to: Client.Repositories

  defdelegate read_file(repo, path, ref, access_token), to: Client.Contents
  defdelegate update_file(repo, path, attrs, access_token), to: Client.Contents

  defdelegate list_issues(repo, state, access_token), to: Client.Issues
  defdelegate create_issue(repo, attrs, access_token), to: Client.Issues
  defdelegate update_issue(repo, issue_number, attrs, access_token), to: Client.Issues
  defdelegate add_issue_labels(repo, issue_number, labels, access_token), to: Client.Issues
  defdelegate remove_issue_label(repo, issue_number, label, access_token), to: Client.Issues
  defdelegate assign_issue(repo, issue_number, assignees, access_token), to: Client.Issues
  defdelegate create_issue_comment(repo, issue_number, body, access_token), to: Client.Issues
  defdelegate list_issue_comments(params, access_token), to: Client.Issues
  defdelegate close_issue(repo, number, access_token), to: Client.Issues
  defdelegate list_new_issues(repo, checkpoint, access_token), to: Client.Issues

  defdelegate list_pull_requests(params, access_token), to: Client.PullRequests
  defdelegate get_pull_request(repo, pull_number, access_token), to: Client.PullRequests
  defdelegate list_pull_request_files(params, access_token), to: Client.PullRequests
  defdelegate create_pull_request(repo, attrs, access_token), to: Client.PullRequests
  defdelegate update_pull_request(repo, pull_number, attrs, access_token), to: Client.PullRequests

  defdelegate request_pull_request_reviewers(repo, pull_number, attrs, access_token),
    to: Client.PullRequests

  defdelegate create_pull_request_review_comment(repo, pull_number, attrs, access_token),
    to: Client.PullRequests

  defdelegate merge_pull_request(repo, pull_number, attrs, access_token), to: Client.PullRequests
  defdelegate list_updated_pull_requests(repo, checkpoint, access_token), to: Client.PullRequests

  defdelegate list_workflow_runs(params, access_token), to: Client.Actions
  defdelegate list_workflow_run_jobs(params, access_token), to: Client.Actions
  defdelegate rerun_workflow_run(repo, run_id, opts, access_token), to: Client.Actions
  defdelegate cancel_workflow_run(repo, run_id, access_token), to: Client.Actions
  defdelegate dispatch_workflow(repo, workflow, attrs, access_token), to: Client.Actions

  defdelegate list_releases(params, access_token), to: Client.Releases
  defdelegate create_release(repo, attrs, access_token), to: Client.Releases
  defdelegate upload_release_asset(upload_url, attrs, access_token), to: Client.Releases

  defdelegate search_issues(params, access_token), to: Client.Search
  defdelegate search_repositories(params, access_token), to: Client.Search

  defdelegate fetch_authenticated_user(access_token), to: Client.Identity
  defdelegate fetch_installation(installation_id, access_token), to: Client.Installations
end
