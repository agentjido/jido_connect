defmodule Jido.Connect.Linear.Client do
  @moduledoc """
  Linear GraphQL client boundary.

  New code should prefer the API-area modules under `Jido.Connect.Linear.Client.*`
  for a narrower dependency surface.
  """

  alias Jido.Connect.Linear.Client.{Response, Transport}

  @get_issue_query """
  query GetIssue($id: String!) {
    issue(id: $id) {
      id
      identifier
      title
      description
      state { id name type color }
      priority
      priorityLabel
      team { id key name }
      assignee { id name email displayName }
      creator { id name email displayName }
      labels { nodes { id name color } }
      createdAt
      updatedAt
    }
  }
  """

  @search_issues_query """
  query SearchIssues($filter: IssueFilter, $first: Int, $after: String, $orderBy: PaginationOrderBy) {
    issues(filter: $filter, first: $first, after: $after, orderBy: $orderBy) {
      nodes {
        id
        identifier
        title
        description
        state { id name type color }
        priority
        priorityLabel
        team { id key name }
        assignee { id name email displayName }
        labels { nodes { id name color } }
        createdAt
        updatedAt
      }
      pageInfo { hasNextPage endCursor }
      totalCount
    }
  }
  """

  @create_issue_mutation """
  mutation CreateIssue($input: IssueCreateInput!) {
    issueCreate(input: $input) {
      success
      issue {
        id
        identifier
        title
      }
    }
  }
  """

  @update_issue_mutation """
  mutation UpdateIssue($id: String!, $input: IssueUpdateInput!) {
    issueUpdate(id: $id, input: $input) {
      success
      issue {
        id
        identifier
        title
      }
    }
  }
  """

  @list_teams_query """
  query ListTeams($first: Int, $after: String) {
    teams(first: $first, after: $after) {
      nodes {
        id
        key
        name
        description
        icon
        color
      }
      pageInfo { hasNextPage endCursor }
    }
  }
  """

  @create_comment_mutation """
  mutation CreateComment($input: CommentCreateInput!) {
    commentCreate(input: $input) {
      success
      comment {
        id
        body
        createdAt
      }
    }
  }
  """

  @doc "Fetches a single Linear issue by ID."
  def get_issue(issue_id, access_token, _opts \\ [])
      when is_binary(issue_id) and is_binary(access_token) do
    variables = %{id: issue_id}

    access_token
    |> Transport.request()
    |> Transport.graphql(@get_issue_query, variables)
    |> Response.handle_issue_response()
  end

  @doc "Searches Linear issues using a filter."
  def search_issues(filter, access_token, opts \\ [])
      when is_map(filter) and is_binary(access_token) do
    variables = %{
      filter: filter,
      first: Keyword.get(opts, :first, 50),
      after: Keyword.get(opts, :after),
      orderBy: Keyword.get(opts, :order_by, "updatedAt")
    }

    variables = if variables.after, do: variables, else: Map.delete(variables, :after)

    access_token
    |> Transport.request()
    |> Transport.graphql(@search_issues_query, variables)
    |> Response.handle_issue_search_response()
  end

  @doc "Creates a new Linear issue."
  def create_issue(attrs, access_token) when is_map(attrs) and is_binary(access_token) do
    input = build_issue_input(attrs)

    access_token
    |> Transport.request()
    |> Transport.graphql(@create_issue_mutation, %{input: input})
    |> Response.handle_issue_create_response()
  end

  @doc "Updates an existing Linear issue."
  def update_issue(issue_id, fields, access_token)
      when is_binary(issue_id) and is_map(fields) and is_binary(access_token) do
    input = build_update_input(fields)

    access_token
    |> Transport.request()
    |> Transport.graphql(@update_issue_mutation, %{id: issue_id, input: input})
    |> Response.handle_issue_update_response()
  end

  @doc "Lists Linear teams visible to the authenticated user."
  def list_teams(access_token, opts \\ [])
      when is_binary(access_token) and is_list(opts) do
    variables = %{
      first: Keyword.get(opts, :first, 50),
      after: Keyword.get(opts, :after)
    }

    variables = if variables.after, do: variables, else: Map.delete(variables, :after)

    access_token
    |> Transport.request()
    |> Transport.graphql(@list_teams_query, variables)
    |> Response.handle_team_list_response()
  end

  @doc "Adds a comment to a Linear issue."
  def add_comment(issue_id, body_text, access_token)
      when is_binary(issue_id) and is_binary(body_text) and is_binary(access_token) do
    input = %{
      issueId: issue_id,
      body: body_text
    }

    access_token
    |> Transport.request()
    |> Transport.graphql(@create_comment_mutation, %{input: input})
    |> Response.handle_comment_response()
  end

  @doc "Returns the configured or injected client module."
  def resolve(%{linear_client: client}) when is_atom(client), do: client
  def resolve(_credentials), do: __MODULE__

  @doc "Extracts the bearer token from credential fields."
  def credential_token(credentials) do
    Map.get(credentials, :api_key) || Map.get(credentials, :access_token)
  end

  defp build_issue_input(attrs) do
    base = %{
      teamId: Map.get(attrs, :team_id),
      title: Map.get(attrs, :title)
    }

    base
    |> maybe_put(:description, Map.get(attrs, :description))
    |> maybe_put(:priority, parse_priority(Map.get(attrs, :priority)))
    |> maybe_put(:assigneeId, Map.get(attrs, :assignee_id))
    |> maybe_put(:labelIds, Map.get(attrs, :labels))
  end

  defp build_update_input(fields) do
    base = %{}

    base
    |> maybe_put(:title, Map.get(fields, :title))
    |> maybe_put(:description, Map.get(fields, :description))
    |> maybe_put(:priority, parse_priority(Map.get(fields, :priority)))
    |> maybe_put(:stateId, Map.get(fields, :status))
    |> maybe_put(:assigneeId, Map.get(fields, :assignee_id))
    |> maybe_put(:labelIds, Map.get(fields, :labels))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp parse_priority(nil), do: nil
  defp parse_priority(priority) when is_integer(priority), do: priority

  defp parse_priority("urgent"), do: 1
  defp parse_priority("high"), do: 2
  defp parse_priority("medium"), do: 3
  defp parse_priority("low"), do: 4
  defp parse_priority("no_priority"), do: 0
  defp parse_priority(_), do: nil
end
