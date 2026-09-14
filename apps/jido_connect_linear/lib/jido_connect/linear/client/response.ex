defmodule Jido.Connect.Linear.Client.Response do
  @moduledoc "Linear GraphQL success and error response handling."

  alias Jido.Connect.Data
  alias Jido.Connect.Linear.Client.{Normalizer, Transport}

  @doc "Handles a GraphQL response, extracting data or errors."
  def handle_graphql_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    case Data.get(body, "errors") do
      errors when is_list(errors) and length(errors) > 0 ->
        Transport.handle_error_response(
          {:ok, %{status: status, body: body}},
          message: "Linear GraphQL errors",
          reason: :graphql_error
        )

      _nil_or_empty ->
        case Data.get(body, "data") do
          data when is_map(data) ->
            {:ok, data}

          _other ->
            Transport.invalid_success_response("Linear GraphQL response was invalid", body)
        end
    end
  end

  def handle_graphql_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Linear GraphQL response was invalid", body)
  end

  def handle_graphql_response(response), do: Transport.handle_error_response(response)

  @doc "Handles a single Linear issue get response."
  def handle_issue_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    case Data.get(body, "errors") do
      errors when is_list(errors) and length(errors) > 0 ->
        Transport.handle_error_response(
          {:ok, %{status: status, body: body}},
          message: "Linear GraphQL errors",
          reason: :graphql_error
        )

      _ ->
        case get_in(body, ["data", "issue"]) do
          issue when is_map(issue) -> {:ok, normalize_issue(issue)}
          _ -> Transport.invalid_success_response("Linear issue response was invalid", body)
        end
    end
  end

  def handle_issue_response(response), do: Transport.handle_error_response(response)

  @doc "Handles a Linear issue search response."
  def handle_issue_search_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    case Data.get(body, "errors") do
      errors when is_list(errors) and length(errors) > 0 ->
        Transport.handle_error_response(
          {:ok, %{status: status, body: body}},
          message: "Linear GraphQL errors",
          reason: :graphql_error
        )

      _ ->
        case get_in(body, ["data", "issues"]) do
          result when is_map(result) ->
            nodes = Data.get(result, "nodes", [])
            page_info = Data.get(result, "pageInfo", %{})

            {:ok,
             %{
               issues: Enum.map(nodes, &normalize_issue/1),
               has_next_page: Data.get(page_info, "hasNextPage", false),
               end_cursor: Data.get(page_info, "endCursor"),
               total_count: Data.get(result, "totalCount")
             }}

          _ ->
            Transport.invalid_success_response("Linear issue search response was invalid", body)
        end
    end
  end

  def handle_issue_search_response(response), do: Transport.handle_error_response(response)

  @doc "Handles a Linear issue create response."
  def handle_issue_create_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    case Data.get(body, "errors") do
      errors when is_list(errors) and length(errors) > 0 ->
        Transport.handle_error_response(
          {:ok, %{status: status, body: body}},
          message: "Linear GraphQL errors",
          reason: :graphql_error
        )

      _ ->
        case get_in(body, ["data", "issueCreate", "issue"]) do
          issue when is_map(issue) ->
            {:ok, normalize_issue(issue)}

          _ ->
            Transport.invalid_success_response("Linear issue create response was invalid", body)
        end
    end
  end

  def handle_issue_create_response(response), do: Transport.handle_error_response(response)

  @doc "Handles a Linear issue update response."
  def handle_issue_update_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    case Data.get(body, "errors") do
      errors when is_list(errors) and length(errors) > 0 ->
        Transport.handle_error_response(
          {:ok, %{status: status, body: body}},
          message: "Linear GraphQL errors",
          reason: :graphql_error
        )

      _ ->
        case get_in(body, ["data", "issueUpdate", "success"]) do
          true ->
            {:ok, %{updated: true}}

          _ ->
            Transport.invalid_success_response("Linear issue update response was invalid", body)
        end
    end
  end

  def handle_issue_update_response(response), do: Transport.handle_error_response(response)

  @doc "Handles a Linear team list response."
  def handle_team_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    case Data.get(body, "errors") do
      errors when is_list(errors) and length(errors) > 0 ->
        Transport.handle_error_response(
          {:ok, %{status: status, body: body}},
          message: "Linear GraphQL errors",
          reason: :graphql_error
        )

      _ ->
        case get_in(body, ["data", "teams"]) do
          result when is_map(result) ->
            nodes = Data.get(result, "nodes", [])
            page_info = Data.get(result, "pageInfo", %{})

            {:ok,
             %{
               teams: Enum.map(nodes, &normalize_team/1),
               has_next_page: Data.get(page_info, "hasNextPage", false),
               end_cursor: Data.get(page_info, "endCursor")
             }}

          _ ->
            Transport.invalid_success_response("Linear team list response was invalid", body)
        end
    end
  end

  def handle_team_list_response(response), do: Transport.handle_error_response(response)

  @doc "Handles a Linear comment create response."
  def handle_comment_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    case Data.get(body, "errors") do
      errors when is_list(errors) and length(errors) > 0 ->
        Transport.handle_error_response(
          {:ok, %{status: status, body: body}},
          message: "Linear GraphQL errors",
          reason: :graphql_error
        )

      _ ->
        case get_in(body, ["data", "commentCreate", "comment"]) do
          comment when is_map(comment) ->
            {:ok,
             %{
               id: Data.get(comment, "id"),
               body: Data.get(comment, "body"),
               created_at: Data.get(comment, "createdAt")
             }}

          _ ->
            Transport.invalid_success_response("Linear comment response was invalid", body)
        end
    end
  end

  def handle_comment_response(response), do: Transport.handle_error_response(response)

  @doc "Handles a Linear comments list response."
  def handle_comments_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    case Data.get(body, "errors") do
      errors when is_list(errors) and length(errors) > 0 ->
        Transport.handle_error_response(
          {:ok, %{status: status, body: body}},
          message: "Linear GraphQL errors",
          reason: :graphql_error
        )

      _ ->
        case get_in(body, ["data", "comments"]) do
          result when is_map(result) ->
            nodes = Data.get(result, "nodes", [])
            page_info = Data.get(result, "pageInfo", %{})

            {:ok,
             %{
               comments: Enum.map(nodes, &normalize_comment/1),
               has_next_page: Data.get(page_info, "hasNextPage", false),
               end_cursor: Data.get(page_info, "endCursor"),
               total_count: Data.get(result, "totalCount")
             }}

          _ ->
            Transport.invalid_success_response(
              "Linear comments list response was invalid",
              body
            )
        end
    end
  end

  def handle_comments_list_response(response), do: Transport.handle_error_response(response)

  @doc "Handles a Linear team get response."
  def handle_team_get_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    case Data.get(body, "errors") do
      errors when is_list(errors) and length(errors) > 0 ->
        Transport.handle_error_response(
          {:ok, %{status: status, body: body}},
          message: "Linear GraphQL errors",
          reason: :graphql_error
        )

      _ ->
        case get_in(body, ["data", "team"]) do
          team when is_map(team) -> {:ok, normalize_team(team)}
          _ -> Transport.invalid_success_response("Linear team get response was invalid", body)
        end
    end
  end

  def handle_team_get_response(response), do: Transport.handle_error_response(response)

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp normalize_issue(payload) when is_map(payload) do
    case Normalizer.issue(payload) do
      {:ok, issue} -> Normalizer.action_issue(issue)
      {:error, _reason} -> nil
    end
  end

  defp normalize_issue(_payload), do: nil

  defp normalize_user(nil), do: nil

  defp normalize_user(user) when is_map(user) do
    %{
      id: Data.get(user, "id"),
      name: Data.get(user, "name"),
      email: Data.get(user, "email"),
      display_name: Data.get(user, "displayName")
    }
    |> Data.compact()
  end

  defp normalize_team(payload) when is_map(payload) do
    %{
      id: Data.get(payload, "id"),
      key: Data.get(payload, "key"),
      name: Data.get(payload, "name"),
      description: Data.get(payload, "description"),
      icon: Data.get(payload, "icon"),
      color: Data.get(payload, "color"),
      lead: normalize_user(Data.get(payload, "lead"))
    }
    |> Data.compact()
  end

  defp normalize_team(_payload), do: nil

  defp normalize_comment(payload) when is_map(payload) do
    %{
      id: Data.get(payload, "id"),
      body: Data.get(payload, "body"),
      author: normalize_user(Data.get(payload, "user")),
      parent_id: Data.get(payload, "parentId"),
      created_at: Data.get(payload, "createdAt"),
      updated_at: Data.get(payload, "updatedAt")
    }
    |> Data.compact()
  end

  defp normalize_comment(_payload), do: nil
end
