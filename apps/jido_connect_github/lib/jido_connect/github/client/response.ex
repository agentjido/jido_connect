defmodule Jido.Connect.GitHub.Client.Response do
  @moduledoc "GitHub REST success and error response handling."

  alias Jido.Connect.{Data, Error}
  alias Jido.Connect.GitHub.Client.{Normalizer, Params, Transport}

  import Normalizer

  def handle_user_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    {:ok, normalize_authenticated_user(body)}
  end

  def handle_user_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    Transport.invalid_success_response("GitHub authenticated user response was invalid", body)
  end

  def handle_user_response(response), do: handle_error_response(response)

  def handle_user_installation_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    case {Data.get(body, "installations"), Data.get(body, "total_count")} do
      {installations, total_count} when is_list(installations) and is_integer(total_count) ->
        {:ok,
         %{
           installations: Enum.map(installations, &normalize_user_installation/1),
           total_count: total_count
         }}

      _other ->
        Transport.invalid_success_response("GitHub installation list response was invalid", body)
    end
  end

  def handle_user_installation_list_response(response), do: handle_error_response(response)

  def handle_rate_limit_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    case Data.get(body, "resources") do
      resources when is_map(resources) -> {:ok, %{resources: normalize_rate_resources(resources)}}
      _other -> Transport.invalid_success_response("GitHub rate limit response was invalid", body)
    end
  end

  def handle_rate_limit_response(response), do: handle_error_response(response)

  def handle_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_list(body) do
    {:ok, Enum.map(body, &normalize_issue/1)}
  end

  def handle_list_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    Transport.invalid_success_response("GitHub list issues response was invalid", body)
  end

  def handle_list_response(response), do: handle_error_response(response)

  def handle_repository_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    case Data.get(body, "repositories") do
      repositories when is_list(repositories) ->
        {:ok,
         %{
           repositories: Enum.map(repositories, &normalize_repository/1),
           total_count: Data.get(body, "total_count")
         }}

      _other ->
        Transport.invalid_success_response("GitHub repository list response was invalid", body)
    end
  end

  def handle_repository_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("GitHub repository list response was invalid", body)
  end

  def handle_repository_list_response(response), do: handle_error_response(response)

  def handle_user_repository_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_list(body) do
    {:ok,
     %{
       repositories: Enum.map(body, &normalize_repository/1),
       total_count: length(body)
     }}
  end

  def handle_user_repository_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("GitHub repository list response was invalid", body)
  end

  def handle_user_repository_list_response(response), do: handle_error_response(response)

  def handle_repository_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    {:ok, normalize_repository(body)}
  end

  def handle_repository_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("GitHub repository response was invalid", body)
  end

  def handle_repository_response(response), do: handle_error_response(response)

  def handle_branch_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_list(body) do
    {:ok, Enum.map(body, &normalize_branch/1)}
  end

  def handle_branch_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("GitHub branch list response was invalid", body)
  end

  def handle_branch_list_response(response), do: handle_error_response(response)

  def handle_ref_fetch_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    {:ok, normalize_ref(body)}
  end

  def handle_ref_fetch_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("GitHub ref response was invalid", body)
  end

  def handle_ref_fetch_response(response), do: handle_error_response(response)

  def handle_ref_create_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    {:ok, normalize_ref(body)}
  end

  def handle_ref_create_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("GitHub ref create response was invalid", body)
  end

  def handle_ref_create_response({:ok, %{status: 422, body: body} = response}) do
    if Params.ref_already_exists?(body) do
      {:error,
       Error.provider("GitHub branch already exists",
         provider: :github,
         reason: :already_exists,
         status: 422,
         details: %{message: Data.get(body, "message"), body: body}
       )}
    else
      handle_error_response({:ok, response})
    end
  end

  def handle_ref_create_response(response), do: handle_error_response(response)

  def handle_commit_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_list(body) do
    {:ok, Enum.map(body, &normalize_commit/1)}
  end

  def handle_commit_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("GitHub commit list response was invalid", body)
  end

  def handle_commit_list_response(response), do: handle_error_response(response)

  def handle_compare_refs_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    {:ok, normalize_comparison(body)}
  end

  def handle_compare_refs_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("GitHub compare refs response was invalid", body)
  end

  def handle_compare_refs_response(response), do: handle_error_response(response)

  def handle_file_content_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    case Data.get(body, "type") do
      "file" ->
        normalize_file_content(body)

      _other ->
        Transport.invalid_success_response("GitHub file content response was invalid", body)
    end
  end

  def handle_file_content_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("GitHub file content response was invalid", body)
  end

  def handle_file_content_response(response), do: handle_error_response(response)

  def handle_file_update_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    {:ok, normalize_file_update(body)}
  end

  def handle_file_update_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("GitHub file update response was invalid", body)
  end

  def handle_file_update_response(response), do: handle_error_response(response)

  def handle_pull_request_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_list(body) do
    {:ok, Enum.map(body, &normalize_pull_request/1)}
  end

  def handle_pull_request_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("GitHub pull request list response was invalid", body)
  end

  def handle_pull_request_list_response(response), do: handle_error_response(response)

  def handle_search_issue_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    case Data.get(body, "items") do
      items when is_list(items) ->
        {:ok,
         %{
           results: Enum.map(items, &normalize_search_issue/1),
           total_count: Data.get(body, "total_count")
         }}

      _other ->
        Transport.invalid_success_response("GitHub issue search response was invalid", body)
    end
  end

  def handle_search_issue_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("GitHub issue search response was invalid", body)
  end

  def handle_search_issue_response(response), do: handle_error_response(response)

  def handle_updated_pull_request_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    case Data.get(body, "items") do
      items when is_list(items) ->
        {:ok, Enum.map(items, &normalize_pull_request_search_result/1)}

      _other ->
        Transport.invalid_success_response(
          "GitHub pull request search response was invalid",
          body
        )
    end
  end

  def handle_updated_pull_request_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("GitHub pull request search response was invalid", body)
  end

  def handle_updated_pull_request_list_response(response), do: handle_error_response(response)

  def handle_search_repository_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    case Data.get(body, "items") do
      items when is_list(items) ->
        {:ok,
         %{
           repositories: Enum.map(items, &normalize_search_repository/1),
           total_count: Data.get(body, "total_count")
         }}

      _other ->
        Transport.invalid_success_response("GitHub repository search response was invalid", body)
    end
  end

  def handle_search_repository_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("GitHub repository search response was invalid", body)
  end

  def handle_search_repository_response(response), do: handle_error_response(response)

  def handle_pull_request_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    {:ok, normalize_pull_request_details(body)}
  end

  def handle_pull_request_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("GitHub pull request response was invalid", body)
  end

  def handle_pull_request_response(response), do: handle_error_response(response)

  def handle_pull_request_review_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_list(body) do
    {:ok, Enum.map(body, &normalize_pull_request_review/1)}
  end

  def handle_pull_request_review_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("GitHub pull request review response was invalid", body)
  end

  def handle_pull_request_review_list_response(response), do: handle_error_response(response)

  def handle_pull_request_requested_reviewer_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    case {Data.get(body, "users"), Data.get(body, "teams")} do
      {users, teams} when is_list(users) and is_list(teams) ->
        {:ok,
         %{
           users: Enum.map(users, &normalize_user/1),
           teams: Enum.map(teams, &normalize_team/1)
         }}

      _other ->
        Transport.invalid_success_response("GitHub requested reviewer response was invalid", body)
    end
  end

  def handle_pull_request_requested_reviewer_response(response),
    do: handle_error_response(response)

  def handle_check_run_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    case {Data.get(body, "check_runs"), Data.get(body, "total_count")} do
      {check_runs, total_count} when is_list(check_runs) and is_integer(total_count) ->
        {:ok,
         %{
           check_runs: Enum.map(check_runs, &normalize_check_run/1),
           total_count: total_count
         }}

      _other ->
        Transport.invalid_success_response("GitHub check run response was invalid", body)
    end
  end

  def handle_check_run_list_response(response), do: handle_error_response(response)

  def handle_commit_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    {:ok, normalize_commit(body)}
  end

  def handle_commit_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    Transport.invalid_success_response("GitHub commit response was invalid", body)
  end

  def handle_commit_response(response), do: handle_error_response(response)

  def handle_git_tree_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    case {Data.get(body, "sha"), Data.get(body, "tree"), Data.get(body, "truncated")} do
      {sha, entries, truncated}
      when is_binary(sha) and is_list(entries) and is_boolean(truncated) ->
        {:ok,
         %{
           sha: sha,
           entries: Enum.map(entries, &normalize_git_tree_entry/1),
           truncated: truncated
         }}

      _other ->
        Transport.invalid_success_response("GitHub Git tree response was invalid", body)
    end
  end

  def handle_git_tree_response(response), do: handle_error_response(response)

  def handle_git_blob_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    case {Data.get(body, "sha"), Data.get(body, "encoding"), Data.get(body, "size"),
          Data.get(body, "content")} do
      {sha, encoding, size, content}
      when is_binary(sha) and is_binary(encoding) and is_integer(size) and size >= 0 and
             is_binary(content) ->
        {:ok, %{sha: sha, encoding: encoding, size: size, content: content}}

      _other ->
        Transport.invalid_success_response("GitHub Git blob response was invalid", body)
    end
  end

  def handle_git_blob_response(response), do: handle_error_response(response)

  def handle_pull_request_file_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_list(body) do
    {:ok, Enum.map(body, &normalize_pull_request_file/1)}
  end

  def handle_pull_request_file_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("GitHub pull request file list response was invalid", body)
  end

  def handle_pull_request_file_list_response(response), do: handle_error_response(response)

  def handle_workflow_run_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    case Data.get(body, "workflow_runs") do
      workflow_runs when is_list(workflow_runs) ->
        {:ok,
         %{
           workflow_runs: Enum.map(workflow_runs, &normalize_workflow_run/1),
           total_count: Data.get(body, "total_count")
         }}

      _other ->
        Transport.invalid_success_response("GitHub workflow run list response was invalid", body)
    end
  end

  def handle_workflow_run_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("GitHub workflow run list response was invalid", body)
  end

  def handle_workflow_run_list_response(response), do: handle_error_response(response)

  def handle_release_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_list(body) do
    {:ok, Enum.map(body, &normalize_release/1)}
  end

  def handle_release_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("GitHub release list response was invalid", body)
  end

  def handle_release_list_response(response), do: handle_error_response(response)

  def handle_release_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    {:ok, normalize_release(body)}
  end

  def handle_release_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("GitHub release response was invalid", body)
  end

  def handle_release_response(response), do: handle_error_response(response)

  def handle_release_asset_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    {:ok, normalize_release_asset(body)}
  end

  def handle_release_asset_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("GitHub release asset response was invalid", body)
  end

  def handle_release_asset_response(response), do: handle_error_response(response)

  def handle_tag_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_list(body) do
    {:ok, Enum.map(body, &normalize_tag/1)}
  end

  def handle_tag_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("GitHub tag list response was invalid", body)
  end

  def handle_tag_list_response(response), do: handle_error_response(response)

  def handle_workflow_run_job_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    case Data.get(body, "jobs") do
      jobs when is_list(jobs) ->
        normalized_jobs = Enum.map(jobs, &normalize_workflow_run_job/1)

        {:ok,
         %{
           jobs: normalized_jobs,
           total_count: Data.get(body, "total_count"),
           ci_status: aggregate_ci_status(normalized_jobs)
         }}

      _other ->
        Transport.invalid_success_response(
          "GitHub workflow run job list response was invalid",
          body
        )
    end
  end

  def handle_workflow_run_job_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("GitHub workflow run job list response was invalid", body)
  end

  def handle_workflow_run_job_list_response(response), do: handle_error_response(response)

  def handle_workflow_run_rerun_response({:ok, %{status: 201}}) do
    {:ok, %{rerun_requested: true}}
  end

  def handle_workflow_run_rerun_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("GitHub workflow run rerun response was invalid", body)
  end

  def handle_workflow_run_rerun_response(response), do: handle_error_response(response)

  def handle_workflow_run_cancel_response({:ok, %{status: 202}}) do
    {:ok, %{cancel_requested: true}}
  end

  def handle_workflow_run_cancel_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("GitHub workflow run cancel response was invalid", body)
  end

  def handle_workflow_run_cancel_response(response), do: handle_error_response(response)

  def handle_workflow_dispatch_response({:ok, %{status: 204}}), do: {:ok, %{dispatched: true}}

  def handle_workflow_dispatch_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("GitHub workflow dispatch response was invalid", body)
  end

  def handle_workflow_dispatch_response(response), do: handle_error_response(response)

  def handle_pull_request_merge_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    {:ok, normalize_pull_request_merge(body)}
  end

  def handle_pull_request_merge_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("GitHub pull request merge response was invalid", body)
  end

  def handle_pull_request_merge_response(response), do: handle_error_response(response)

  def handle_pull_request_reviewers_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    {:ok, normalize_pull_request_reviewers(body)}
  end

  def handle_pull_request_reviewers_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("GitHub pull request reviewers response was invalid", body)
  end

  def handle_pull_request_reviewers_response(response), do: handle_error_response(response)

  def handle_pull_request_review_comment_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    {:ok, normalize_pull_request_review_comment(body)}
  end

  def handle_pull_request_review_comment_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response(
      "GitHub pull request review comment response was invalid",
      body
    )
  end

  def handle_pull_request_review_comment_response(response), do: handle_error_response(response)

  def handle_issue_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    {:ok, normalize_issue(body)}
  end

  def handle_issue_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    Transport.invalid_success_response("GitHub issue response was invalid", body)
  end

  def handle_issue_response(response), do: handle_error_response(response)

  def handle_label_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_list(body) do
    {:ok, normalize_labels(body)}
  end

  def handle_label_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("GitHub label list response was invalid", body)
  end

  def handle_label_list_response(response), do: handle_error_response(response)

  def handle_issue_assignment_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    {:ok, normalize_assigned_issue(body)}
  end

  def handle_issue_assignment_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("GitHub issue assignment response was invalid", body)
  end

  def handle_issue_assignment_response(response), do: handle_error_response(response)

  def handle_comment_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    {:ok, normalize_comment(body)}
  end

  def handle_comment_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    Transport.invalid_success_response("GitHub comment response was invalid", body)
  end

  def handle_comment_response(response), do: handle_error_response(response)

  def handle_comment_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_list(body) do
    {:ok, Enum.map(body, &normalize_comment/1)}
  end

  def handle_comment_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("GitHub issue comment list response was invalid", body)
  end

  def handle_comment_list_response(response), do: handle_error_response(response)

  def handle_map_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    {:ok, body}
  end

  def handle_map_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    Transport.invalid_success_response("GitHub response was invalid", body)
  end

  def handle_map_response(response), do: handle_error_response(response)

  def handle_issue_context_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    {:ok, normalize_issue_context(body)}
  end

  def handle_issue_context_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("GitHub issue context response was invalid", body)
  end

  def handle_issue_context_response(response), do: handle_error_response(response)

  def handle_error_response(response),
    do: Transport.handle_error_response(response)
end
