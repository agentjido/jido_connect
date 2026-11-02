defmodule Jido.Connect.Jira.Client.Normalizer do
  @moduledoc "Jira Cloud REST response normalization helpers."

  alias Jido.Connect.Data
  alias Jido.Connect.Jira.Client.Normalizer.IssueFields

  alias Jido.Connect.Jira.{
    ADFText,
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

  @doc """
  Normalizes a Jira issue into a stable struct.

  The description is rendered with `Jido.Connect.Jira.ADFText`:
  `description_unsupported_nodes` lists the ADF node and mark types skipped
  while rendering it. A malformed ADF description returns the projection's
  `Jido.Connect.Error.ValidationError`.

  Pass the request's field list as `requested_fields:` to fill
  `missing_fields` with the requested keys that the payload leaves out; use
  `["*all"]` when the request named no fields. Without the option the list
  stays empty. `*all` and `*navigable` count as the fields this function
  reads, `timetracking` only for `*all`; other fields behind them and other
  `*` selectors are not checked. A list that names no field, such as
  `["-description"]`, starts from `*all`, as an issue read does; pass
  `["*navigable" | list]` for enhanced search, which starts it from
  `*navigable`.
  """
  @spec issue(map(), keyword()) :: {:ok, Issue.t()} | {:error, term()}
  def issue(payload, opts \\ [])

  def issue(payload, opts) when is_map(payload) and is_list(opts) do
    fields = Data.get(payload, "fields") || %{}

    with {:ok, description} <- ADFText.project(Data.get(fields, "description")) do
      %{
        key: Data.get(payload, "key"),
        id: Data.get(payload, "id"),
        url: Data.get(payload, "self"),
        summary: Data.get(fields, "summary"),
        description: ADFText.text(description),
        description_unsupported_nodes: ADFText.unsupported_nodes(description),
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
      |> Map.put(:missing_fields, IssueFields.missing(fields, opts[:requested_fields]))
      |> Issue.new()
    end
  end

  def issue(_payload, _opts), do: {:error, :invalid_issue_payload}

  @doc """
  Normalizes a Jira issue into a consistent map shape (legacy helper).

  Returns `nil` when `issue/1` fails, including for a malformed ADF
  description.
  """
  def normalize_issue(payload) when is_map(payload) do
    case issue(payload) do
      {:ok, struct} -> issue_map(struct)
      {:error, _} -> nil
    end
  end

  def normalize_issue(_payload), do: nil

  @doc """
  Returns the map shape of a normalized issue, without metadata.

  The nested status, assignee and reporter become plain maps too, as the
  `:map` outputs of the generated actions require.
  """
  @spec issue_map(Issue.t()) :: map()
  def issue_map(%Issue{} = issue) do
    issue
    |> plain_map()
    |> Map.update!(:status, &plain_map/1)
    |> Map.update!(:assignee, &plain_map/1)
    |> Map.update!(:reporter, &plain_map/1)
  end

  defp plain_map(nil), do: nil

  defp plain_map(struct) when is_struct(struct),
    do: struct |> Map.from_struct() |> Map.drop([:metadata])

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

  @doc """
  Normalizes a Jira comment into a stable struct.

  The body is rendered with `Jido.Connect.Jira.ADFText`:
  `body_unsupported_nodes` lists the ADF node and mark types skipped while
  rendering it, and `body_adf` keeps the original ADF document. An empty
  document keeps `body: ""`, so it stays apart from a comment without a body.
  A malformed ADF body returns the projection's
  `Jido.Connect.Error.ValidationError`.

  `url` is Jira's `self`; `visibility` is Jira's visibility restriction,
  unchanged.
  """
  @spec comment(map()) :: {:ok, Comment.t()} | {:error, term()}
  def comment(payload) when is_map(payload) do
    raw_body = Data.get(payload, "body")

    with {:ok, body} <- ADFText.project(raw_body) do
      %{
        id: Data.get(payload, "id"),
        url: Data.get(payload, "self"),
        body_adf: if(is_map(raw_body), do: raw_body),
        body_unsupported_nodes: ADFText.unsupported_nodes(body),
        rendered_body: Data.get(payload, "renderedBody"),
        author: normalize_user(Data.get(payload, "author")),
        update_author: normalize_user(Data.get(payload, "updateAuthor")),
        created_at: Data.get(payload, "created"),
        updated_at: Data.get(payload, "updated"),
        visibility: Data.get(payload, "visibility"),
        jsd_public: Data.get(payload, "jsdPublic")
      }
      |> Data.compact()
      |> put_text(:body, ADFText.text(body))
      |> Comment.new()
    end
  end

  def comment(_payload), do: {:error, :invalid_comment_payload}

  @doc """
  Returns the map shape of a normalized comment, without metadata.

  Keys without a value are left out, also in the nested author and update
  author, which become plain maps as the `:map` outputs of the generated
  actions require.
  """
  @spec comment_map(Comment.t()) :: map()
  def comment_map(%Comment{} = comment) do
    comment
    |> present_map()
    |> Map.new(fn
      {key, %User{} = user} -> {key, present_map(user)}
      pair -> pair
    end)
  end

  defp present_map(struct) when is_struct(struct) do
    struct
    |> Map.from_struct()
    |> Map.drop([:metadata])
    |> Map.reject(fn {_key, value} -> is_nil(value) end)
  end

  # `Data.compact/1` also drops "", the text of an empty document.
  defp put_text(map, _key, nil), do: map
  defp put_text(map, key, text), do: Map.put(map, key, text)

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

  # Each nested helper normalizes an object and passes `nil` or any other
  # value through unchanged, so the struct rejects a value that is not an
  # object instead of the helper raising.

  defp normalize_status(status) when is_map(status) do
    case status(status) do
      {:ok, s} -> s
      {:error, _} -> nil
    end
  end

  defp normalize_status(other), do: other

  defp normalize_user(user) when is_map(user) do
    case user(user) do
      {:ok, u} -> u
      {:error, _} -> nil
    end
  end

  defp normalize_user(other), do: other

  defp normalize_project_brief(project) when is_map(project) do
    %{
      key: Data.get(project, "key"),
      name: Data.get(project, "name"),
      id: Data.get(project, "id")
    }
    |> Data.compact()
  end

  defp normalize_project_brief(other), do: other

  defp normalize_issue_type(type) when is_map(type) do
    %{
      name: Data.get(type, "name"),
      id: Data.get(type, "id"),
      subtask: Data.get(type, "subtask")
    }
    |> Data.compact()
  end

  defp normalize_issue_type(other), do: other

  defp normalize_priority(priority) when is_map(priority) do
    %{
      name: Data.get(priority, "name"),
      id: Data.get(priority, "id")
    }
    |> Data.compact()
  end

  defp normalize_priority(other), do: other
end
