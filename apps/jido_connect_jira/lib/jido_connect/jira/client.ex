defmodule Jido.Connect.Jira.Client do
  @moduledoc """
  Jira Cloud REST client boundary.

  New code should prefer the API-area modules under `Jido.Connect.Jira.Client.*`
  for a narrower dependency surface.
  """

  alias Jido.Connect.Jira.Client.{Response, Transport}

  @doc "Fetches a single Jira issue by key."
  def get_issue(issue_key, access_token, opts \\ [])
      when is_binary(issue_key) and is_binary(access_token) do
    fields = Keyword.get(opts, :fields)

    params =
      if fields do
        %{fields: Enum.join(fields, ",")}
      else
        %{}
      end

    access_token
    |> Transport.request()
    |> Req.get(url: "/rest/api/3/issue/#{issue_key}", params: params)
    |> Response.handle_issue_response()
  end

  @doc "Searches Jira issues using JQL."
  def search_issues(jql, access_token, opts \\ [])
      when is_binary(jql) and is_binary(access_token) do
    fields = Keyword.get(opts, :fields)

    body = %{
      jql: jql,
      startAt: Keyword.get(opts, :start_at, 0),
      maxResults: Keyword.get(opts, :max_results, 50)
    }

    body =
      if fields do
        Map.put(body, :fields, fields)
      else
        Map.put(
          body,
          :fields,
          Keyword.get(opts, :fields, ["summary", "status", "assignee", "updated"])
        )
      end

    access_token
    |> Transport.request()
    |> Req.post(url: "/rest/api/3/search", json: body)
    |> Response.handle_issue_search_response()
  end

  @doc "Creates a new Jira issue."
  def create_issue(attrs, access_token) when is_map(attrs) and is_binary(access_token) do
    body = %{fields: attrs}

    access_token
    |> Transport.request()
    |> Req.post(url: "/rest/api/3/issue", json: body)
    |> Response.handle_issue_create_response()
  end

  @doc "Lists Jira projects visible to the authenticated user."
  def list_projects(access_token, opts \\ [])
      when is_binary(access_token) and is_list(opts) do
    params =
      %{
        startAt: Keyword.get(opts, :start_at, 0),
        maxResults: Keyword.get(opts, :max_results, 50)
      }
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    access_token
    |> Transport.request()
    |> Req.get(url: "/rest/api/3/project/search", params: params)
    |> Response.handle_project_list_response()
  end

  @doc "Fetches a single Jira project by key or ID."
  def get_project(project_key, access_token, opts \\ [])
      when is_binary(project_key) and is_binary(access_token) and is_list(opts) do
    access_token
    |> Transport.request()
    |> Req.get(url: "/rest/api/3/project/#{project_key}")
    |> Response.handle_project_response()
  end

  @doc "Updates an existing Jira issue."
  def update_issue(issue_key, fields, access_token)
      when is_binary(issue_key) and is_map(fields) and is_binary(access_token) do
    body = %{fields: fields}

    access_token
    |> Transport.request()
    |> Req.put(url: "/rest/api/3/issue/#{issue_key}", json: body)
    |> Response.handle_update_response()
  end

  @doc "Transitions a Jira issue to a new status."
  def transition_issue(issue_key, transition_id, access_token, opts \\ [])
      when is_binary(issue_key) and is_binary(transition_id) and is_binary(access_token) do
    body = %{transition: %{id: transition_id}}

    body =
      case Keyword.get(opts, :fields) do
        nil -> body
        fields -> Map.put(body, :fields, fields)
      end

    access_token
    |> Transport.request()
    |> Req.post(url: "/rest/api/3/issue/#{issue_key}/transitions", json: body)
    |> Response.handle_transition_response()
  end

  @doc "Assigns a Jira issue to a user by account ID."
  def assign_issue(issue_key, account_id, access_token)
      when is_binary(issue_key) and is_binary(account_id) and is_binary(access_token) do
    body = %{accountId: account_id}

    access_token
    |> Transport.request()
    |> Req.put(url: "/rest/api/3/issue/#{issue_key}/assignee", json: body)
    |> Response.handle_assign_response()
  end

  @doc "Adds a comment to a Jira issue."
  def add_comment(issue_key, body_text, access_token)
      when is_binary(issue_key) and is_binary(body_text) and is_binary(access_token) do
    body = %{
      body: %{
        type: "doc",
        version: 1,
        content: [
          %{type: "paragraph", content: [%{type: "text", text: body_text}]}
        ]
      }
    }

    access_token
    |> Transport.request()
    |> Req.post(url: "/rest/api/3/issue/#{issue_key}/comment", json: body)
    |> Response.handle_comment_response()
  end

  @doc "Lists all Jira field schemas (system and custom)."
  def list_field_schemas(access_token, opts \\ [])
      when is_binary(access_token) and is_list(opts) do
    params =
      case Keyword.get(opts, :expand) do
        nil -> %{}
        expand -> %{expand: expand}
      end

    access_token
    |> Transport.request()
    |> Req.get(url: "/rest/api/3/field", params: params)
    |> Response.handle_field_schema_list_response()
  end

  @doc "Returns the configured or injected client module."
  def resolve(%{jira_client: client}) when is_atom(client), do: client
  def resolve(_credentials), do: __MODULE__

  @doc "Extracts the bearer token from credential fields."
  def credential_token(credentials) do
    Map.get(credentials, :api_key) || Map.get(credentials, :access_token)
  end
end
