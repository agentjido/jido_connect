defmodule Jido.Connect.GitHub.Client.Normalizer do
  @moduledoc "GitHub REST response normalization helpers."

  alias Jido.Connect.Data
  alias Jido.Connect.GitHub.Client.Transport

  def normalize_issue(issue) when is_map(issue) do
    %{
      id: Data.get(issue, "id"),
      number: Data.get(issue, "number"),
      url: Data.get(issue, "html_url") || Data.get(issue, "url"),
      title: Data.get(issue, "title"),
      state: Data.get(issue, "state"),
      user: normalize_user(Data.get(issue, "user")),
      created_at: Data.get(issue, "created_at"),
      updated_at: Data.get(issue, "updated_at"),
      closed_at: Data.get(issue, "closed_at"),
      pull_request: Data.get(issue, "pull_request")
    }
    |> Data.compact()
  end

  def normalize_assigned_issue(issue) when is_map(issue) do
    issue
    |> normalize_issue()
    |> Map.put(:assignees, normalize_users(Data.get(issue, "assignees")))
  end

  def normalize_repository(repository) when is_map(repository) do
    %{
      id: Data.get(repository, "id"),
      name: Data.get(repository, "name"),
      full_name: Data.get(repository, "full_name"),
      owner: normalize_repository_owner(Data.get(repository, "owner")),
      private: Data.get(repository, "private"),
      visibility: Data.get(repository, "visibility"),
      default_branch: Data.get(repository, "default_branch"),
      permissions: Data.get(repository, "permissions"),
      url: Data.get(repository, "html_url") || Data.get(repository, "url"),
      archived: Data.get(repository, "archived"),
      fork: Data.get(repository, "fork"),
      updated_at: Data.get(repository, "updated_at")
    }
    |> Data.compact()
  end

  def normalize_branch(branch) when is_map(branch) do
    commit = Data.get(branch, "commit") || %{}

    %{
      name: Data.get(branch, "name"),
      sha: Data.get(commit, "sha"),
      commit: normalize_branch_commit(commit),
      protected: Data.get(branch, "protected"),
      protection_url: Data.get(branch, "protection_url")
    }
  end

  def normalize_branch_commit(commit) when is_map(commit) do
    %{
      sha: Data.get(commit, "sha"),
      url: Data.get(commit, "url")
    }
  end

  def normalize_branch_commit(_commit), do: nil

  def normalize_ref(ref) when is_map(ref) do
    object = Data.get(ref, "object") || %{}

    %{
      ref: Data.get(ref, "ref"),
      sha: Data.get(object, "sha"),
      url: Data.get(ref, "url"),
      object: normalize_ref_object(object)
    }
    |> Data.compact()
  end

  def normalize_ref_object(object) when is_map(object) do
    %{
      sha: Data.get(object, "sha"),
      type: Data.get(object, "type"),
      url: Data.get(object, "url")
    }
    |> Data.compact()
  end

  def normalize_ref_object(_object), do: nil

  def normalize_commit(commit) when is_map(commit) do
    details = Data.get(commit, "commit") || %{}
    author = Data.get(details, "author") || %{}
    committer = Data.get(details, "committer") || %{}

    %{
      sha: Data.get(commit, "sha"),
      url: Data.get(commit, "html_url") || Data.get(commit, "url"),
      message: Data.get(details, "message"),
      author: normalize_commit_actor(Data.get(commit, "author"), author),
      committer: normalize_commit_actor(Data.get(commit, "committer"), committer),
      authored_at: Data.get(author, "date"),
      committed_at: Data.get(committer, "date"),
      parents: normalize_commit_parents(Data.get(commit, "parents"))
    }
    |> Data.compact()
  end

  def normalize_commit_actor(user, commit_actor) do
    actor =
      user
      |> normalize_user()
      |> case do
        nil -> %{}
        normalized -> normalized
      end
      |> Map.merge(%{
        name: Data.get(commit_actor, "name"),
        email: Data.get(commit_actor, "email"),
        date: Data.get(commit_actor, "date")
      })
      |> Data.compact()

    if actor == %{}, do: nil, else: actor
  end

  def normalize_commit_parents(parents) when is_list(parents) do
    Enum.map(parents, fn parent ->
      %{
        sha: Data.get(parent, "sha"),
        url: Data.get(parent, "html_url") || Data.get(parent, "url")
      }
      |> Data.compact()
    end)
  end

  def normalize_commit_parents(_parents), do: []

  def normalize_comparison(comparison) when is_map(comparison) do
    %{
      status: Data.get(comparison, "status"),
      ahead_by: Data.get(comparison, "ahead_by"),
      behind_by: Data.get(comparison, "behind_by"),
      total_commits: Data.get(comparison, "total_commits"),
      commits: normalize_comparison_commits(Data.get(comparison, "commits")),
      files: normalize_comparison_files(Data.get(comparison, "files"))
    }
  end

  def normalize_comparison_commits(commits) when is_list(commits) do
    Enum.map(commits, &normalize_commit/1)
  end

  def normalize_comparison_commits(_commits), do: []

  def normalize_comparison_files(files) when is_list(files) do
    Enum.map(files, &normalize_pull_request_file/1)
  end

  def normalize_comparison_files(_files), do: []

  def normalize_pull_request(pull_request) when is_map(pull_request) do
    %{
      id: Data.get(pull_request, "id"),
      number: Data.get(pull_request, "number"),
      url: Data.get(pull_request, "html_url") || Data.get(pull_request, "url"),
      title: Data.get(pull_request, "title"),
      state: Data.get(pull_request, "state"),
      user: normalize_user(Data.get(pull_request, "user")),
      draft: Data.get(pull_request, "draft"),
      head: normalize_pull_request_ref(Data.get(pull_request, "head")),
      base: normalize_pull_request_ref(Data.get(pull_request, "base")),
      created_at: Data.get(pull_request, "created_at"),
      updated_at: Data.get(pull_request, "updated_at"),
      closed_at: Data.get(pull_request, "closed_at"),
      merged_at: Data.get(pull_request, "merged_at")
    }
    |> Data.compact()
  end

  def normalize_pull_request_search_result(pull_request) when is_map(pull_request) do
    %{
      number: Data.get(pull_request, "number"),
      url: Data.get(pull_request, "html_url") || Data.get(pull_request, "url"),
      title: Data.get(pull_request, "title"),
      state: Data.get(pull_request, "state"),
      updated_at: Data.get(pull_request, "updated_at")
    }
    |> Data.compact()
  end

  def normalize_search_issue(issue) when is_map(issue) do
    %{
      type: search_issue_type(issue),
      number: Data.get(issue, "number"),
      url: Data.get(issue, "html_url") || Data.get(issue, "url"),
      title: Data.get(issue, "title"),
      state: Data.get(issue, "state"),
      user: normalize_user(Data.get(issue, "user")),
      labels: normalize_labels(Data.get(issue, "labels")),
      comments: Data.get(issue, "comments"),
      created_at: Data.get(issue, "created_at"),
      updated_at: Data.get(issue, "updated_at")
    }
    |> Data.compact()
  end

  def search_issue_type(issue) do
    if Data.get(issue, "pull_request"), do: :pull_request, else: :issue
  end

  def normalize_search_repository(repository) when is_map(repository) do
    repository
    |> normalize_repository()
    |> Map.merge(%{
      description: Data.get(repository, "description"),
      language: Data.get(repository, "language"),
      stargazers_count: Data.get(repository, "stargazers_count"),
      forks_count: Data.get(repository, "forks_count"),
      open_issues_count: Data.get(repository, "open_issues_count"),
      archived: Data.get(repository, "archived"),
      fork: Data.get(repository, "fork"),
      updated_at: Data.get(repository, "updated_at"),
      pushed_at: Data.get(repository, "pushed_at")
    })
    |> Data.compact()
  end

  def normalize_pull_request_details(pull_request) when is_map(pull_request) do
    pull_request
    |> normalize_pull_request()
    |> Map.merge(%{
      body: Data.get(pull_request, "body"),
      maintainer_can_modify: Data.get(pull_request, "maintainer_can_modify"),
      merged: Data.get(pull_request, "merged"),
      mergeable: Data.get(pull_request, "mergeable"),
      rebaseable: Data.get(pull_request, "rebaseable"),
      mergeable_state: Data.get(pull_request, "mergeable_state"),
      merge_commit_sha: Data.get(pull_request, "merge_commit_sha"),
      commits: Data.get(pull_request, "commits"),
      additions: Data.get(pull_request, "additions"),
      deletions: Data.get(pull_request, "deletions"),
      changed_files: Data.get(pull_request, "changed_files"),
      labels: normalize_labels(Data.get(pull_request, "labels")),
      issue: nil
    })
    |> Data.compact()
  end

  def normalize_authenticated_user(user) when is_map(user) do
    %{
      id: Data.get(user, "id"),
      login: Data.get(user, "login"),
      type: Data.get(user, "type"),
      url: Data.get(user, "html_url") || Data.get(user, "url")
    }
    |> Data.compact()
  end

  def normalize_user_installation(installation) when is_map(installation) do
    %{
      id: Data.get(installation, "id"),
      account: normalize_repository_owner(Data.get(installation, "account")),
      repository_selection: Data.get(installation, "repository_selection"),
      permissions: Data.get(installation, "permissions") || %{},
      app_id: Data.get(installation, "app_id")
    }
    |> Data.compact()
  end

  def normalize_rate_resources(resources) when is_map(resources) do
    resources
    |> Enum.map(fn {name, value} -> {to_string(name), normalize_rate(value)} end)
    |> Map.new()
  end

  def normalize_rate(rate) when is_map(rate) do
    %{
      limit: Data.get(rate, "limit"),
      remaining: Data.get(rate, "remaining"),
      reset: Data.get(rate, "reset"),
      used: Data.get(rate, "used")
    }
    |> Data.compact()
  end

  def normalize_rate(_rate), do: %{}

  def normalize_pull_request_review(review) when is_map(review) do
    %{
      id: Data.get(review, "id"),
      user: normalize_user(Data.get(review, "user")),
      state: Data.get(review, "state"),
      submitted_at: Data.get(review, "submitted_at"),
      commit_id: Data.get(review, "commit_id")
    }
    |> Data.compact()
  end

  def normalize_check_run(check_run) when is_map(check_run) do
    %{
      id: Data.get(check_run, "id"),
      name: Data.get(check_run, "name"),
      app: normalize_check_run_app(Data.get(check_run, "app")),
      status: Data.get(check_run, "status"),
      conclusion: Data.get(check_run, "conclusion"),
      started_at: Data.get(check_run, "started_at"),
      completed_at: Data.get(check_run, "completed_at"),
      url: Data.get(check_run, "html_url") || Data.get(check_run, "url")
    }
    |> Data.compact()
  end

  def normalize_check_run_app(app) when is_map(app) do
    %{id: Data.get(app, "id"), slug: Data.get(app, "slug")}
    |> Data.compact()
  end

  def normalize_check_run_app(_app), do: nil

  def normalize_git_tree_entry(entry) when is_map(entry) do
    %{
      path: Data.get(entry, "path"),
      mode: Data.get(entry, "mode"),
      type: Data.get(entry, "type"),
      sha: Data.get(entry, "sha"),
      size: Data.get(entry, "size"),
      url: Data.get(entry, "url")
    }
    |> Data.compact()
  end

  def normalize_pull_request_file(file) when is_map(file) do
    %{
      filename: Data.get(file, "filename"),
      status: Data.get(file, "status"),
      additions: Data.get(file, "additions"),
      deletions: Data.get(file, "deletions"),
      changes: Data.get(file, "changes"),
      sha: Data.get(file, "sha"),
      previous_filename: Data.get(file, "previous_filename"),
      blob_url: Data.get(file, "blob_url"),
      raw_url: Data.get(file, "raw_url"),
      contents_url: Data.get(file, "contents_url"),
      patch: Data.get(file, "patch")
    }
    |> Data.compact()
  end

  def normalize_comment(comment) when is_map(comment) do
    %{
      id: Data.get(comment, "id"),
      url: Data.get(comment, "html_url") || Data.get(comment, "url"),
      body: Data.get(comment, "body"),
      user: normalize_user(Data.get(comment, "user")),
      author_association: Data.get(comment, "author_association"),
      created_at: Data.get(comment, "created_at"),
      updated_at: Data.get(comment, "updated_at")
    }
    |> Data.compact()
  end

  def normalize_pull_request_merge(result) when is_map(result) do
    %{
      sha: Data.get(result, "sha"),
      merged: Data.get(result, "merged"),
      message: Data.get(result, "message")
    }
    |> Data.compact()
  end

  def normalize_pull_request_reviewers(pull_request) when is_map(pull_request) do
    pull_request
    |> normalize_pull_request()
    |> Map.put(
      :requested_reviewers,
      normalize_users(Data.get(pull_request, "requested_reviewers"))
    )
    |> Map.put(:requested_teams, normalize_teams(Data.get(pull_request, "requested_teams")))
  end

  def normalize_pull_request_review_comment(comment) when is_map(comment) do
    comment
    |> normalize_comment()
    |> Map.merge(%{
      path: Data.get(comment, "path"),
      position: Data.get(comment, "position"),
      original_position: Data.get(comment, "original_position"),
      commit_id: Data.get(comment, "commit_id"),
      original_commit_id: Data.get(comment, "original_commit_id"),
      diff_hunk: Data.get(comment, "diff_hunk"),
      line: Data.get(comment, "line"),
      original_line: Data.get(comment, "original_line"),
      side: Data.get(comment, "side"),
      start_line: Data.get(comment, "start_line"),
      original_start_line: Data.get(comment, "original_start_line"),
      start_side: Data.get(comment, "start_side")
    })
    |> Data.compact()
  end

  def normalize_workflow_run(workflow_run) when is_map(workflow_run) do
    %{
      id: Data.get(workflow_run, "id"),
      name: Data.get(workflow_run, "name"),
      number: Data.get(workflow_run, "run_number"),
      status: Data.get(workflow_run, "status"),
      conclusion: Data.get(workflow_run, "conclusion"),
      event: Data.get(workflow_run, "event"),
      branch: Data.get(workflow_run, "head_branch"),
      sha: Data.get(workflow_run, "head_sha"),
      workflow_id: Data.get(workflow_run, "workflow_id"),
      attempt: Data.get(workflow_run, "run_attempt"),
      url: Data.get(workflow_run, "html_url") || Data.get(workflow_run, "url"),
      created_at: Data.get(workflow_run, "created_at"),
      updated_at: Data.get(workflow_run, "updated_at")
    }
    |> Data.compact()
  end

  def normalize_release(release) when is_map(release) do
    %{
      id: Data.get(release, "id"),
      tag_name: Data.get(release, "tag_name"),
      name: Data.get(release, "name"),
      draft: Data.get(release, "draft"),
      prerelease: Data.get(release, "prerelease"),
      target_commitish: Data.get(release, "target_commitish"),
      author: normalize_user(Data.get(release, "author")),
      url: Data.get(release, "html_url") || Data.get(release, "url"),
      upload_url: Data.get(release, "upload_url"),
      tarball_url: Data.get(release, "tarball_url"),
      zipball_url: Data.get(release, "zipball_url"),
      created_at: Data.get(release, "created_at"),
      published_at: Data.get(release, "published_at"),
      body: Data.get(release, "body")
    }
    |> Data.compact()
  end

  def normalize_release_asset(asset) when is_map(asset) do
    %{
      id: Data.get(asset, "id"),
      node_id: Data.get(asset, "node_id"),
      name: Data.get(asset, "name"),
      label: Data.get(asset, "label"),
      state: Data.get(asset, "state"),
      content_type: Data.get(asset, "content_type"),
      size: Data.get(asset, "size"),
      download_count: Data.get(asset, "download_count"),
      url: Data.get(asset, "url"),
      browser_download_url: Data.get(asset, "browser_download_url"),
      created_at: Data.get(asset, "created_at"),
      updated_at: Data.get(asset, "updated_at"),
      uploader: normalize_user(Data.get(asset, "uploader"))
    }
    |> Data.compact()
  end

  def normalize_tag(tag) when is_map(tag) do
    commit = Data.get(tag, "commit")

    %{
      name: Data.get(tag, "name"),
      sha: Data.get(commit || %{}, "sha"),
      url: Data.get(commit || %{}, "url") || Data.get(tag, "zipball_url") || Data.get(tag, "url")
    }
    |> Data.compact()
  end

  def normalize_workflow_run_job(job) when is_map(job) do
    %{
      id: Data.get(job, "id"),
      run_id: Data.get(job, "run_id"),
      run_attempt: Data.get(job, "run_attempt"),
      name: Data.get(job, "name"),
      status: Data.get(job, "status"),
      conclusion: Data.get(job, "conclusion"),
      ci_status: normalize_ci_status(Data.get(job, "status"), Data.get(job, "conclusion")),
      steps: normalize_workflow_run_steps(Data.get(job, "steps")),
      url: Data.get(job, "html_url") || Data.get(job, "url"),
      started_at: Data.get(job, "started_at"),
      completed_at: Data.get(job, "completed_at")
    }
    |> Data.compact()
  end

  def normalize_workflow_run_steps(steps) when is_list(steps) do
    Enum.map(steps, &normalize_workflow_run_step/1)
  end

  def normalize_workflow_run_steps(_steps), do: []

  def normalize_workflow_run_step(step) when is_map(step) do
    %{
      number: Data.get(step, "number"),
      name: Data.get(step, "name"),
      status: Data.get(step, "status"),
      conclusion: Data.get(step, "conclusion"),
      ci_status: normalize_ci_status(Data.get(step, "status"), Data.get(step, "conclusion")),
      started_at: Data.get(step, "started_at"),
      completed_at: Data.get(step, "completed_at")
    }
    |> Data.compact()
  end

  def normalize_repository_owner(owner) when is_map(owner) do
    %{
      login: Data.get(owner, "login"),
      id: Data.get(owner, "id"),
      type: Data.get(owner, "type"),
      url: Data.get(owner, "html_url") || Data.get(owner, "url")
    }
    |> Data.compact()
  end

  def normalize_repository_owner(_owner), do: nil

  def normalize_file_content(file) when is_map(file) do
    with "base64" <- Data.get(file, "encoding"),
         content when is_binary(content) <- Data.get(file, "content"),
         {:ok, decoded} <- Base.decode64(content, ignore: :whitespace) do
      decoded_file_content(file, decoded, content)
    else
      _other ->
        Transport.invalid_success_response("GitHub file content response was invalid", file)
    end
  end

  def decoded_file_content(file, decoded, encoded) do
    base = %{
      path: Data.get(file, "path"),
      name: Data.get(file, "name"),
      sha: Data.get(file, "sha"),
      size: Data.get(file, "size"),
      type: Data.get(file, "type"),
      url: Data.get(file, "url"),
      html_url: Data.get(file, "html_url"),
      download_url: Data.get(file, "download_url")
    }

    content =
      if text_content?(decoded) do
        %{content: decoded, content_base64: nil, encoding: "utf-8", binary: false}
      else
        %{
          content: nil,
          content_base64: strip_base64_whitespace(encoded),
          encoding: "base64",
          binary: true
        }
      end

    {:ok, compact_file_content(Map.merge(Data.compact(base), content))}
  end

  def strip_base64_whitespace(content) do
    String.replace(content, ~r/\s+/, "")
  end

  def text_content?(content) do
    String.valid?(content) and :binary.match(content, <<0>>) == :nomatch
  end

  def compact_file_content(file) do
    file
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  def normalize_file_update(result) when is_map(result) do
    content = Data.get(result, "content") || %{}
    commit = Data.get(result, "commit") || %{}

    %{
      sha: Data.get(content, "sha"),
      url: Data.get(content, "url"),
      html_url: Data.get(content, "html_url"),
      download_url: Data.get(content, "download_url"),
      commit_sha: Data.get(commit, "sha"),
      commit_message: Data.get(commit, "message")
    }
    |> Data.compact()
  end

  def normalize_pull_request_ref(ref) when is_map(ref) do
    %{
      label: Data.get(ref, "label"),
      ref: Data.get(ref, "ref"),
      sha: Data.get(ref, "sha"),
      repo: normalize_pull_request_ref_repo(Data.get(ref, "repo"))
    }
    |> Data.compact()
  end

  def normalize_pull_request_ref(_ref), do: nil

  def normalize_pull_request_ref_repo(repo) when is_map(repo) do
    %{
      id: Data.get(repo, "id"),
      name: Data.get(repo, "name"),
      full_name: Data.get(repo, "full_name"),
      url: Data.get(repo, "html_url") || Data.get(repo, "url")
    }
    |> Data.compact()
  end

  def normalize_pull_request_ref_repo(_repo), do: nil

  def normalize_issue_context(issue) when is_map(issue) do
    %{
      number: Data.get(issue, "number"),
      url: Data.get(issue, "html_url") || Data.get(issue, "url"),
      title: Data.get(issue, "title"),
      state: Data.get(issue, "state"),
      labels: normalize_labels(Data.get(issue, "labels")),
      assignees: normalize_users(Data.get(issue, "assignees")),
      milestone: normalize_milestone(Data.get(issue, "milestone"))
    }
    |> Data.compact()
  end

  def normalize_labels(labels) when is_list(labels) do
    Enum.map(labels, fn label ->
      %{
        name: Data.get(label, "name"),
        color: Data.get(label, "color"),
        description: Data.get(label, "description")
      }
      |> Data.compact()
    end)
  end

  def normalize_labels(_labels), do: []

  def normalize_users(users) when is_list(users), do: Enum.map(users, &normalize_user/1)
  def normalize_users(_users), do: []

  def normalize_user(user) when is_map(user) do
    %{
      login: Data.get(user, "login"),
      id: Data.get(user, "id"),
      type: Data.get(user, "type"),
      url: Data.get(user, "html_url") || Data.get(user, "url")
    }
    |> Data.compact()
  end

  def normalize_user(_user), do: nil

  def normalize_teams(teams) when is_list(teams), do: Enum.map(teams, &normalize_team/1)
  def normalize_teams(_teams), do: []

  def normalize_team(team) when is_map(team) do
    %{
      id: Data.get(team, "id"),
      name: Data.get(team, "name"),
      slug: Data.get(team, "slug"),
      description: Data.get(team, "description"),
      privacy: Data.get(team, "privacy"),
      url: Data.get(team, "html_url") || Data.get(team, "url")
    }
    |> Data.compact()
  end

  def normalize_team(_team), do: nil

  def normalize_milestone(milestone) when is_map(milestone) do
    %{
      number: Data.get(milestone, "number"),
      title: Data.get(milestone, "title"),
      state: Data.get(milestone, "state"),
      description: Data.get(milestone, "description"),
      due_on: Data.get(milestone, "due_on")
    }
    |> Data.compact()
  end

  def normalize_milestone(_milestone), do: nil

  def normalize_ci_status(_status, conclusion) when conclusion in ["success", "failure"] do
    conclusion
  end

  def normalize_ci_status(_status, conclusion)
      when conclusion in ["cancelled", "skipped", "timed_out", "action_required", "neutral"] do
    conclusion
  end

  def normalize_ci_status(status, _conclusion)
      when status in ["queued", "waiting", "requested"] do
    "queued"
  end

  def normalize_ci_status(status, _conclusion) when status in ["in_progress", "pending"] do
    "in_progress"
  end

  def normalize_ci_status("completed", _conclusion), do: "unknown"
  def normalize_ci_status(status, _conclusion) when is_binary(status), do: status
  def normalize_ci_status(_status, _conclusion), do: "unknown"

  def aggregate_ci_status([]), do: "unknown"

  def aggregate_ci_status(jobs) do
    statuses = Enum.map(jobs, &Map.get(&1, :ci_status, "unknown"))

    cond do
      "failure" in statuses -> "failure"
      "timed_out" in statuses -> "timed_out"
      "action_required" in statuses -> "action_required"
      "cancelled" in statuses -> "cancelled"
      "in_progress" in statuses -> "in_progress"
      "queued" in statuses -> "queued"
      Enum.all?(statuses, &(&1 == "success")) -> "success"
      Enum.all?(statuses, &(&1 == "skipped")) -> "skipped"
      Enum.all?(statuses, &(&1 in ["success", "skipped", "neutral"])) -> "neutral"
      true -> "unknown"
    end
  end
end
