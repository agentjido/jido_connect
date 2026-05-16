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
    body = %{
      jql: jql,
      startAt: Keyword.get(opts, :start_at, 0),
      maxResults: Keyword.get(opts, :max_results, 50),
      fields: Keyword.get(opts, :fields, ["summary", "status", "assignee", "updated"])
    }

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

  @doc "Returns the configured or injected client module."
  def resolve(%{jira_client: client}) when is_atom(client), do: client
  def resolve(_credentials), do: __MODULE__

  @doc "Extracts the bearer token from credential fields."
  def credential_token(credentials) do
    Map.get(credentials, :api_key) || Map.get(credentials, :access_token)
  end
end
