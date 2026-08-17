defmodule Jido.Connect.Jira.Client do
  @moduledoc """
  Jira Cloud REST client boundary.

  Each call receives a Jira client request. The request binds the selected
  connection, its auth profile, its endpoint, and its leased credential fields.
  """

  alias Jido.Connect.Jira.Client.{Request, Response, Transport}

  @doc "Builds a request from the provider handler runtime."
  defdelegate request_context(runtime), to: Request, as: :from_runtime

  @doc "Returns the injected provider client or the built-in client."
  def resolve(%{provider_client: client}) when is_atom(client) and not is_nil(client), do: client
  def resolve(_runtime), do: __MODULE__

  @doc "Fetches a single Jira issue by key."
  def get_issue(issue_key, %Request{} = request, opts \\ []) when is_binary(issue_key) do
    fields = Keyword.get(opts, :fields)
    params = if fields, do: %{fields: Enum.join(fields, ",")}, else: %{}

    request
    |> Transport.request()
    |> Req.get(url: Request.url(request, "/rest/api/3/issue/#{issue_key}"), params: params)
    |> Response.handle_issue_response()
  end

  @doc "Searches Jira issues using JQL."
  def search_issues(jql, %Request{} = request, opts \\ []) when is_binary(jql) do
    fields = Keyword.get(opts, :fields)

    body = %{
      jql: jql,
      startAt: Keyword.get(opts, :start_at, 0),
      maxResults: Keyword.get(opts, :max_results, 50),
      fields: fields || ["summary", "status", "assignee", "updated"]
    }

    request
    |> Transport.request()
    |> Req.post(url: Request.url(request, "/rest/api/3/search"), json: body)
    |> Response.handle_issue_search_response()
  end

  @doc "Creates a new Jira issue."
  def create_issue(attrs, %Request{} = request) when is_map(attrs) do
    request
    |> Transport.request()
    |> Req.post(url: Request.url(request, "/rest/api/3/issue"), json: %{fields: attrs})
    |> Response.handle_issue_create_response()
  end

  @doc "Lists Jira projects visible to the authenticated user."
  def list_projects(%Request{} = request, opts \\ []) when is_list(opts) do
    params = %{
      startAt: Keyword.get(opts, :start_at, 0),
      maxResults: Keyword.get(opts, :max_results, 50)
    }

    request
    |> Transport.request()
    |> Req.get(url: Request.url(request, "/rest/api/3/project/search"), params: params)
    |> Response.handle_project_list_response()
  end

  @doc "Fetches a single Jira project by key or ID."
  def get_project(project_key, %Request{} = request, _opts \\ []) when is_binary(project_key) do
    request
    |> Transport.request()
    |> Req.get(url: Request.url(request, "/rest/api/3/project/#{project_key}"))
    |> Response.handle_project_response()
  end

  @doc "Updates an existing Jira issue."
  def update_issue(issue_key, fields, %Request{} = request)
      when is_binary(issue_key) and is_map(fields) do
    request
    |> Transport.request()
    |> Req.put(
      url: Request.url(request, "/rest/api/3/issue/#{issue_key}"),
      json: %{fields: fields}
    )
    |> Response.handle_update_response()
  end

  @doc "Transitions a Jira issue to a new status."
  def transition_issue(issue_key, transition_id, %Request{} = request, opts \\ [])
      when is_binary(issue_key) and is_binary(transition_id) do
    body = %{transition: %{id: transition_id}}
    body = if fields = Keyword.get(opts, :fields), do: Map.put(body, :fields, fields), else: body

    request
    |> Transport.request()
    |> Req.post(
      url: Request.url(request, "/rest/api/3/issue/#{issue_key}/transitions"),
      json: body
    )
    |> Response.handle_transition_response()
  end

  @doc "Assigns a Jira issue to a user by account ID."
  def assign_issue(issue_key, account_id, %Request{} = request)
      when is_binary(issue_key) and is_binary(account_id) do
    request
    |> Transport.request()
    |> Req.put(
      url: Request.url(request, "/rest/api/3/issue/#{issue_key}/assignee"),
      json: %{accountId: account_id}
    )
    |> Response.handle_assign_response()
  end

  @doc "Adds a comment to a Jira issue."
  def add_comment(issue_key, body_text, %Request{} = request)
      when is_binary(issue_key) and is_binary(body_text) do
    body = %{
      body: %{
        type: "doc",
        version: 1,
        content: [%{type: "paragraph", content: [%{type: "text", text: body_text}]}]
      }
    }

    request
    |> Transport.request()
    |> Req.post(
      url: Request.url(request, "/rest/api/3/issue/#{issue_key}/comment"),
      json: body
    )
    |> Response.handle_comment_response()
  end

  @doc "Lists all Jira field schemas."
  def list_field_schemas(%Request{} = request, opts \\ []) when is_list(opts) do
    params = if expand = Keyword.get(opts, :expand), do: %{expand: expand}, else: %{}

    request
    |> Transport.request()
    |> Req.get(url: Request.url(request, "/rest/api/3/field"), params: params)
    |> Response.handle_field_schema_list_response()
  end
end
