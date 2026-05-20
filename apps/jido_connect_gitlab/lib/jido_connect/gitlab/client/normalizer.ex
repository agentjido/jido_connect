defmodule Jido.Connect.GitLab.Client.Normalizer do
  @moduledoc "GitLab REST API response normalization helpers."

  alias Jido.Connect.Data

  alias Jido.Connect.GitLab.{
    Commit,
    Issue,
    Job,
    Label,
    MergeRequest,
    Note,
    Pagination,
    Pipeline,
    Project,
    User
  }

  # ---------------------------------------------------------------------------
  # User
  # ---------------------------------------------------------------------------

  @doc "Normalizes a GitLab user into a stable struct."
  @spec user(map()) :: {:ok, User.t()} | {:error, term()}
  def user(payload) when is_map(payload) do
    %{
      id: Data.get(payload, "id"),
      username: Data.get(payload, "username"),
      name: Data.get(payload, "name"),
      email: Data.get(payload, "email"),
      avatar_url: Data.get(payload, "avatar_url"),
      state: Data.get(payload, "state"),
      web_url: Data.get(payload, "web_url")
    }
    |> Data.compact()
    |> User.new()
  end

  def user(_payload), do: {:error, :invalid_user_payload}

  # ---------------------------------------------------------------------------
  # Project
  # ---------------------------------------------------------------------------

  @doc "Normalizes a GitLab project into a stable struct."
  @spec project(map()) :: {:ok, Project.t()} | {:error, term()}
  def project(payload) when is_map(payload) do
    %{
      id: Data.get(payload, "id"),
      name: Data.get(payload, "name"),
      path: Data.get(payload, "path"),
      path_with_namespace: Data.get(payload, "path_with_namespace"),
      description: Data.get(payload, "description"),
      default_branch: Data.get(payload, "default_branch"),
      visibility: Data.get(payload, "visibility"),
      web_url: Data.get(payload, "web_url"),
      ssh_url: Data.get(payload, "ssh_url_to_repo"),
      http_url: Data.get(payload, "http_url_to_repo"),
      namespace: Data.get(payload, "namespace"),
      owner: normalize_user(Data.get(payload, "owner")),
      star_count: Data.get(payload, "star_count"),
      forks_count: Data.get(payload, "forks_count"),
      open_issues_count: Data.get(payload, "open_issues_count"),
      created_at: Data.get(payload, "created_at"),
      updated_at: Data.get(payload, "updated_at")
    }
    |> Data.compact()
    |> Project.new()
  end

  def project(_payload), do: {:error, :invalid_project_payload}

  # ---------------------------------------------------------------------------
  # Issue
  # ---------------------------------------------------------------------------

  @doc "Normalizes a GitLab issue into a stable struct."
  @spec issue(map()) :: {:ok, Issue.t()} | {:error, term()}
  def issue(payload) when is_map(payload) do
    %{
      id: Data.get(payload, "id"),
      iid: Data.get(payload, "iid"),
      title: Data.get(payload, "title"),
      description: Data.get(payload, "description"),
      state: Data.get(payload, "state"),
      labels: normalize_labels(Data.get(payload, "labels")),
      milestone: Data.get(payload, "milestone"),
      assignees: normalize_users(Data.get(payload, "assignees")),
      author: normalize_user(Data.get(payload, "author")),
      project_id: Data.get(payload, "project_id"),
      web_url: Data.get(payload, "web_url"),
      created_at: Data.get(payload, "created_at"),
      updated_at: Data.get(payload, "updated_at"),
      closed_at: Data.get(payload, "closed_at")
    }
    |> Data.compact()
    |> Issue.new()
  end

  def issue(_payload), do: {:error, :invalid_issue_payload}

  # ---------------------------------------------------------------------------
  # MergeRequest
  # ---------------------------------------------------------------------------

  @doc "Normalizes a GitLab merge request into a stable struct."
  @spec merge_request(map()) :: {:ok, MergeRequest.t()} | {:error, term()}
  def merge_request(payload) when is_map(payload) do
    %{
      id: Data.get(payload, "id"),
      iid: Data.get(payload, "iid"),
      title: Data.get(payload, "title"),
      description: Data.get(payload, "description"),
      state: Data.get(payload, "state"),
      merge_status: Data.get(payload, "merge_status"),
      source_branch: Data.get(payload, "source_branch"),
      target_branch: Data.get(payload, "target_branch"),
      author: normalize_user(Data.get(payload, "author")),
      assignees: normalize_users(Data.get(payload, "assignees")),
      reviewers: normalize_users(Data.get(payload, "reviewers")),
      project_id: Data.get(payload, "project_id"),
      source_project_id: Data.get(payload, "source_project_id"),
      target_project_id: Data.get(payload, "target_project_id"),
      web_url: Data.get(payload, "web_url"),
      created_at: Data.get(payload, "created_at"),
      updated_at: Data.get(payload, "updated_at"),
      merged_at: Data.get(payload, "merged_at"),
      closed_at: Data.get(payload, "closed_at")
    }
    |> Data.compact()
    |> MergeRequest.new()
  end

  def merge_request(_payload), do: {:error, :invalid_merge_request_payload}

  # ---------------------------------------------------------------------------
  # Note
  # ---------------------------------------------------------------------------

  @doc "Normalizes a GitLab note into a stable struct."
  @spec note(map()) :: {:ok, Note.t()} | {:error, term()}
  def note(payload) when is_map(payload) do
    %{
      id: Data.get(payload, "id"),
      body: Data.get(payload, "body"),
      attachment: Data.get(payload, "attachment"),
      author: normalize_user(Data.get(payload, "author")),
      noteable_id: Data.get(payload, "noteable_id"),
      noteable_type: Data.get(payload, "noteable_type"),
      system: Data.get(payload, "system"),
      created_at: Data.get(payload, "created_at"),
      updated_at: Data.get(payload, "updated_at")
    }
    |> Data.compact()
    |> Note.new()
  end

  def note(_payload), do: {:error, :invalid_note_payload}

  # ---------------------------------------------------------------------------
  # Label
  # ---------------------------------------------------------------------------

  @doc "Normalizes a GitLab label into a stable struct."
  @spec label(map()) :: {:ok, Label.t()} | {:error, term()}
  def label(payload) when is_map(payload) do
    %{
      id: Data.get(payload, "id"),
      name: Data.get(payload, "name"),
      color: Data.get(payload, "color"),
      text_color: Data.get(payload, "text_color"),
      description: Data.get(payload, "description")
    }
    |> Data.compact()
    |> Label.new()
  end

  def label(_payload), do: {:error, :invalid_label_payload}

  # ---------------------------------------------------------------------------
  # Pipeline
  # ---------------------------------------------------------------------------

  @doc "Normalizes a GitLab CI/CD pipeline into a stable struct."
  @spec pipeline(map()) :: {:ok, Pipeline.t()} | {:error, term()}
  def pipeline(payload) when is_map(payload) do
    %{
      id: Data.get(payload, "id"),
      sha: Data.get(payload, "sha"),
      ref: Data.get(payload, "ref"),
      status: Data.get(payload, "status"),
      source: Data.get(payload, "source"),
      user: normalize_user(Data.get(payload, "user")),
      project_id: Data.get(payload, "project_id"),
      web_url: Data.get(payload, "web_url"),
      created_at: Data.get(payload, "created_at"),
      updated_at: Data.get(payload, "updated_at"),
      started_at: Data.get(payload, "started_at"),
      finished_at: Data.get(payload, "finished_at")
    }
    |> Data.compact()
    |> Pipeline.new()
  end

  def pipeline(_payload), do: {:error, :invalid_pipeline_payload}

  # ---------------------------------------------------------------------------
  # Job
  # ---------------------------------------------------------------------------

  @doc "Normalizes a GitLab CI/CD job into a stable struct."
  @spec job(map()) :: {:ok, Job.t()} | {:error, term()}
  def job(payload) when is_map(payload) do
    %{
      id: Data.get(payload, "id"),
      name: Data.get(payload, "name"),
      stage: Data.get(payload, "stage"),
      status: Data.get(payload, "status"),
      ref: Data.get(payload, "ref"),
      tag: Data.get(payload, "tag"),
      user: normalize_user(Data.get(payload, "user")),
      pipeline_id: Data.get(payload, "pipeline", []) |> extract_pipeline_id(),
      web_url: Data.get(payload, "web_url"),
      runner: Data.get(payload, "runner"),
      created_at: Data.get(payload, "created_at"),
      started_at: Data.get(payload, "started_at"),
      finished_at: Data.get(payload, "finished_at")
    }
    |> Data.compact()
    |> Job.new()
  end

  def job(_payload), do: {:error, :invalid_job_payload}

  # ---------------------------------------------------------------------------
  # Commit
  # ---------------------------------------------------------------------------

  @doc "Normalizes a GitLab commit into a stable struct."
  @spec commit(map()) :: {:ok, Commit.t()} | {:error, term()}
  def commit(payload) when is_map(payload) do
    %{
      id: Data.get(payload, "id"),
      short_id: Data.get(payload, "short_id"),
      title: Data.get(payload, "title"),
      message: Data.get(payload, "message"),
      author_name: Data.get(payload, "author_name"),
      author_email: Data.get(payload, "author_email"),
      authored_date: Data.get(payload, "authored_date"),
      committer_name: Data.get(payload, "committer_name"),
      committer_email: Data.get(payload, "committer_email"),
      committed_date: Data.get(payload, "committed_date"),
      web_url: Data.get(payload, "web_url")
    }
    |> Data.compact()
    |> Commit.new()
  end

  def commit(_payload), do: {:error, :invalid_commit_payload}

  # ---------------------------------------------------------------------------
  # Pagination
  # ---------------------------------------------------------------------------

  @doc """
  Normalizes GitLab REST API pagination headers or a pagination map.

  GitLab paginates via response headers (`X-Page`, `X-Per-Page`, `X-Total`,
  `X-Total-Pages`, `X-Next-Page`, `X-Prev-Page`). The caller typically
  converts headers to a map before calling this function.
  """
  @spec pagination(map()) :: {:ok, Pagination.t()} | {:error, term()}
  def pagination(payload) when is_map(payload) do
    %{
      page: Data.get(payload, "x-page") || Data.get(payload, "page"),
      per_page: Data.get(payload, "x-per-page") || Data.get(payload, "per_page"),
      total: Data.get(payload, "x-total") || Data.get(payload, "total"),
      total_pages: Data.get(payload, "x-total-pages") || Data.get(payload, "total_pages"),
      next_page: Data.get(payload, "x-next-page") || Data.get(payload, "next_page"),
      prev_page: Data.get(payload, "x-prev-page") || Data.get(payload, "prev_page")
    }
    |> Data.compact()
    |> Pagination.new()
  end

  def pagination(_payload), do: {:error, :invalid_pagination_payload}

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp normalize_user(nil), do: nil

  defp normalize_user(user) when is_map(user) do
    case user(user) do
      {:ok, u} -> u
      {:error, _} -> nil
    end
  end

  defp normalize_users(nil), do: []

  defp normalize_users(users) when is_list(users) do
    users
    |> Enum.map(&normalize_user/1)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_users(_), do: []

  defp normalize_labels(nil), do: []

  defp normalize_labels(labels) when is_list(labels) do
    labels
    |> Enum.map(&normalize_label_entry/1)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_labels(_), do: []

  # GitLab may return labels as string names or full objects.
  defp normalize_label_entry(label) when is_map(label) do
    case label(label) do
      {:ok, l} -> l
      {:error, _} -> nil
    end
  end

  defp normalize_label_entry(label) when is_binary(label) do
    case Label.new(%{id: 0, name: label}) do
      {:ok, l} -> l
      {:error, _} -> nil
    end
  end

  defp normalize_label_entry(_), do: nil

  defp extract_pipeline_id(%{"id" => id}) when is_number(id), do: id
  defp extract_pipeline_id(id) when is_number(id), do: id
  defp extract_pipeline_id(_), do: nil
end
