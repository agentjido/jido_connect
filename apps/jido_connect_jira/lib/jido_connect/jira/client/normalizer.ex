defmodule Jido.Connect.Jira.Client.Normalizer do
  @moduledoc "Jira Cloud REST response normalization helpers."

  alias Jido.Connect.Data

  alias Jido.Connect.Jira.{
    Comment,
    FieldSchema,
    Issue,
    Pagination,
    Project,
    Status,
    Transition,
    User
  }

  # ---------------------------------------------------------------------------
  # Issue
  # ---------------------------------------------------------------------------

  @doc "Normalizes a Jira issue into a stable struct."
  @spec issue(map()) :: {:ok, Issue.t()} | {:error, term()}
  def issue(payload) when is_map(payload) do
    fields = Data.get(payload, "fields") || %{}

    %{
      key: Data.get(payload, "key"),
      id: Data.get(payload, "id"),
      url: Data.get(payload, "self"),
      summary: Data.get(fields, "summary"),
      description: normalize_description(Data.get(fields, "description")),
      status: normalize_status(Data.get(fields, "status")),
      issue_type: normalize_issue_type(Data.get(fields, "issuetype")),
      project: normalize_project_brief(Data.get(fields, "project")),
      assignee: normalize_user(Data.get(fields, "assignee")),
      reporter: normalize_user(Data.get(fields, "reporter")),
      priority: normalize_priority(Data.get(fields, "priority")),
      labels: Data.get(fields, "labels", []),
      components: Data.get(fields, "components", []),
      fix_versions: Data.get(fields, "fixVersions", []),
      due_date: Data.get(fields, "duedate"),
      resolution: Data.get(fields, "resolution"),
      time_tracking: Data.get(fields, "timetracking"),
      created_at: Data.get(fields, "created"),
      updated_at: Data.get(fields, "updated")
    }
    |> Data.compact()
    |> Issue.new()
  end

  def issue(_payload), do: {:error, :invalid_issue_payload}

  @doc "Normalizes a Jira issue into a consistent map shape (legacy helper)."
  def normalize_issue(payload) when is_map(payload) do
    case issue(payload) do
      {:ok, struct} -> Map.from_struct(struct) |> Map.drop([:metadata])
      {:error, _} -> nil
    end
  end

  def normalize_issue(_payload), do: nil

  # ---------------------------------------------------------------------------
  # Project
  # ---------------------------------------------------------------------------

  @doc "Normalizes a Jira project into a stable struct."
  @spec project(map()) :: {:ok, Project.t()} | {:error, term()}
  def project(payload) when is_map(payload) do
    %{
      key: Data.get(payload, "key"),
      id: Data.get(payload, "id"),
      name: Data.get(payload, "name"),
      project_type: Data.get(payload, "projectTypeKey"),
      style: Data.get(payload, "style"),
      url: Data.get(payload, "self"),
      lead: normalize_user(Data.get(payload, "lead")),
      category: Data.get(payload, "projectCategory"),
      description: Data.get(payload, "description"),
      avatar_urls: Data.get(payload, "avatarUrls")
    }
    |> Data.compact()
    |> Project.new()
  end

  def project(_payload), do: {:error, :invalid_project_payload}

  # ---------------------------------------------------------------------------
  # User
  # ---------------------------------------------------------------------------

  @doc "Normalizes a Jira user into a stable struct."
  @spec user(map()) :: {:ok, User.t()} | {:error, term()}
  def user(payload) when is_map(payload) do
    %{
      account_id: Data.get(payload, "accountId"),
      display_name: Data.get(payload, "displayName"),
      email: Data.get(payload, "emailAddress"),
      active: Data.get(payload, "active"),
      avatar_urls: Data.get(payload, "avatarUrls"),
      time_zone: Data.get(payload, "timeZone"),
      locale: Data.get(payload, "locale"),
      account_type: Data.get(payload, "accountType")
    }
    |> Data.compact()
    |> User.new()
  end

  def user(_payload), do: {:error, :invalid_user_payload}

  # ---------------------------------------------------------------------------
  # Comment
  # ---------------------------------------------------------------------------

  @doc "Normalizes a Jira comment into a stable struct."
  @spec comment(map()) :: {:ok, Comment.t()} | {:error, term()}
  def comment(payload) when is_map(payload) do
    %{
      id: Data.get(payload, "id"),
      body: normalize_description(Data.get(payload, "body")),
      rendered_body: Data.get(payload, "renderedBody"),
      author: normalize_user(Data.get(payload, "author")),
      update_author: normalize_user(Data.get(payload, "updateAuthor")),
      created_at: Data.get(payload, "created"),
      updated_at: Data.get(payload, "updated"),
      jsd_public: Data.get(payload, "jsdPublic")
    }
    |> Data.compact()
    |> Comment.new()
  end

  def comment(_payload), do: {:error, :invalid_comment_payload}

  # ---------------------------------------------------------------------------
  # Status
  # ---------------------------------------------------------------------------

  @doc "Normalizes a Jira status into a stable struct."
  @spec status(map()) :: {:ok, Status.t()} | {:error, term()}
  def status(payload) when is_map(payload) do
    %{
      id: Data.get(payload, "id"),
      name: Data.get(payload, "name"),
      category: Data.get(payload, "statusCategory"),
      description: Data.get(payload, "description"),
      icon_url: Data.get(payload, "iconUrl")
    }
    |> Data.compact()
    |> Status.new()
  end

  def status(_payload), do: {:error, :invalid_status_payload}

  # ---------------------------------------------------------------------------
  # Transition
  # ---------------------------------------------------------------------------

  @doc "Normalizes a Jira transition into a stable struct."
  @spec transition(map()) :: {:ok, Transition.t()} | {:error, term()}
  def transition(payload) when is_map(payload) do
    %{
      id: Data.get(payload, "id"),
      name: Data.get(payload, "name"),
      to_status: normalize_status(Data.get(payload, "to")),
      has_screen: Data.get(payload, "hasScreen"),
      is_global: Data.get(payload, "isGlobal"),
      is_initial: Data.get(payload, "isInitial"),
      is_conditional: Data.get(payload, "isConditional"),
      fields: Data.get(payload, "fields")
    }
    |> Data.compact()
    |> Transition.new()
  end

  def transition(_payload), do: {:error, :invalid_transition_payload}

  # ---------------------------------------------------------------------------
  # Field Schema
  # ---------------------------------------------------------------------------

  @doc "Normalizes a Jira field schema entry into a stable struct."
  @spec field_schema(map()) :: {:ok, FieldSchema.t()} | {:error, term()}
  def field_schema(payload) when is_map(payload) do
    %{
      id: Data.get(payload, "id"),
      name: Data.get(payload, "name"),
      key: Data.get(payload, "key"),
      custom: Data.get(payload, "custom"),
      orderable: Data.get(payload, "orderable"),
      navigable: Data.get(payload, "navigable"),
      searchable: Data.get(payload, "searchable"),
      clause_names: Data.get(payload, "clauseNames", []),
      schema: Data.get(payload, "schema")
    }
    |> Data.compact()
    |> FieldSchema.new()
  end

  def field_schema(_payload), do: {:error, :invalid_field_schema_payload}

  # ---------------------------------------------------------------------------
  # Pagination
  # ---------------------------------------------------------------------------

  @doc "Normalizes a Jira pagination envelope into a stable struct."
  @spec pagination(map()) :: {:ok, Pagination.t()} | {:error, term()}
  def pagination(payload) when is_map(payload) do
    %{
      start_at: Data.get(payload, "startAt"),
      max_results: Data.get(payload, "maxResults"),
      total: Data.get(payload, "total"),
      is_last: Data.get(payload, "isLast"),
      next_page_token: Data.get(payload, "nextPageToken")
    }
    |> Data.compact()
    |> Pagination.new()
  end

  def pagination(_payload), do: {:error, :invalid_pagination_payload}

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp normalize_status(nil), do: nil

  defp normalize_status(status) when is_map(status) do
    case status(status) do
      {:ok, s} -> s
      {:error, _} -> nil
    end
  end

  defp normalize_user(nil), do: nil

  defp normalize_user(user) when is_map(user) do
    case user(user) do
      {:ok, u} -> u
      {:error, _} -> nil
    end
  end

  defp normalize_project_brief(nil), do: nil

  defp normalize_project_brief(project) when is_map(project) do
    %{
      key: Data.get(project, "key"),
      name: Data.get(project, "name"),
      id: Data.get(project, "id")
    }
    |> Data.compact()
  end

  defp normalize_issue_type(nil), do: nil

  defp normalize_issue_type(type) when is_map(type) do
    %{
      name: Data.get(type, "name"),
      id: Data.get(type, "id"),
      subtask: Data.get(type, "subtask")
    }
    |> Data.compact()
  end

  defp normalize_priority(nil), do: nil

  defp normalize_priority(priority) when is_map(priority) do
    %{
      name: Data.get(priority, "name"),
      id: Data.get(priority, "id")
    }
    |> Data.compact()
  end

  defp normalize_description(%{"type" => "doc", "content" => content} = _adf)
       when is_list(content) do
    content
    |> extract_text_from_adf()
    |> String.trim()
  end

  defp normalize_description(text) when is_binary(text), do: text
  defp normalize_description(_), do: nil

  defp extract_text_from_adf(nodes) when is_list(nodes) do
    Enum.map_join(nodes, "", &extract_text_from_adf/1)
  end

  defp extract_text_from_adf(%{"content" => content}) when is_list(content) do
    extract_text_from_adf(content)
  end

  defp extract_text_from_adf(%{"text" => text}) when is_binary(text), do: text
  defp extract_text_from_adf(_), do: ""
end
