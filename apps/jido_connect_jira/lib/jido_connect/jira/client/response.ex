defmodule Jido.Connect.Jira.Client.Response do
  @moduledoc "Jira Cloud REST success and error response handling."

  alias Jido.Connect.{Data, Error}
  alias Jido.Connect.Jira.Client.{Normalizer, Transport}

  @issue_invalid "Jira issue response was invalid"
  @search_invalid "Jira issue search response was invalid"

  @doc """
  Handles a single Jira issue get response.

  `requested_fields` is the field list of the request, `["*all"]` when it
  named none; see `Normalizer.issue/2` for `missing_fields`. A description
  that is not valid ADF fails the read with an `:invalid_response` error whose
  details name the field and the projection reason, without the issue content.
  """
  def handle_issue_response(response, requested_fields \\ nil)

  def handle_issue_response({:ok, %{status: status, body: body}}, requested_fields)
      when status in 200..299 and is_map(body) do
    case read_issue(body, requested_fields) do
      :invalid -> {:ok, nil}
      result -> result
    end
  end

  def handle_issue_response({:ok, %{status: status, body: body}}, _requested_fields)
      when status in 200..299 do
    Transport.invalid_success_response(@issue_invalid, body)
  end

  def handle_issue_response(response, _requested_fields),
    do: Transport.handle_error_response(response)

  @doc """
  Handles one page of a Jira enhanced JQL search (`POST /rest/api/3/search/jql`).

  Returns `issues`, `next_page_token` and `is_last`. A page can be empty while
  `is_last` is `false`. `next_page_token` is `nil` on the last page. The
  result never carries `total` or `start_at`, which enhanced search does not
  return.

  A page fails with an `:invalid_response` error whose details name the
  offending key, without page content, when `issues` is not a list, `isLast`
  is not a boolean, `nextPageToken` is neither absent nor a non-empty string,
  a non-final page has no token, or an issue does not normalize. An issue
  whose description is not valid ADF fails the page, as in
  `handle_issue_response/2`.
  """
  def handle_issue_search_response(response, requested_fields \\ nil)

  def handle_issue_search_response({:ok, %{status: status, body: body}}, requested_fields)
      when status in 200..299 and is_map(body) do
    with {:ok, page} <- search_page(body),
         {:ok, issues} <- read_issues(page.issues, requested_fields, body) do
      {:ok, %{page | issues: issues}}
    end
  end

  def handle_issue_search_response({:ok, %{status: status, body: body}}, _requested_fields)
      when status in 200..299 do
    Transport.invalid_success_response(@search_invalid, body)
  end

  def handle_issue_search_response(response, _requested_fields),
    do: Transport.handle_error_response(response)

  @doc "Handles a Jira issue create response."
  def handle_issue_create_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    {:ok, Normalizer.normalize_issue(body)}
  end

  def handle_issue_create_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Jira issue create response was invalid", body)
  end

  def handle_issue_create_response(response), do: Transport.handle_error_response(response)

  @doc "Handles a Jira project list response."
  def handle_project_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    case Data.get(body, "values") do
      values when is_list(values) ->
        {:ok,
         %{
           projects: Enum.map(values, &normalize_project_map/1),
           total: Data.get(body, "total"),
           start_at: Data.get(body, "startAt"),
           max_results: Data.get(body, "maxResults"),
           is_last: Data.get(body, "isLast")
         }}

      _other ->
        Transport.invalid_success_response("Jira project list response was invalid", body)
    end
  end

  def handle_project_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Jira project list response was invalid", body)
  end

  def handle_project_list_response(response), do: Transport.handle_error_response(response)

  @doc "Handles a single Jira project get response."
  def handle_project_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    {:ok, normalize_project_map(body)}
  end

  def handle_project_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    Transport.invalid_success_response("Jira project response was invalid", body)
  end

  def handle_project_response(response), do: Transport.handle_error_response(response)

  @doc "Handles a Jira field schema list response."
  def handle_field_schema_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_list(body) do
    {:ok,
     %{
       fields: Enum.map(body, &normalize_field_schema_map/1),
       total: length(body)
     }}
  end

  def handle_field_schema_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    Transport.invalid_success_response("Jira field schema list response was invalid", body)
  end

  def handle_field_schema_list_response(response), do: Transport.handle_error_response(response)

  @doc "Handles a Jira issue update response (204 No Content)."
  def handle_update_response({:ok, %{status: 204}}) do
    {:ok, %{updated: true}}
  end

  def handle_update_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    {:ok, Normalizer.normalize_issue(body)}
  end

  def handle_update_response(response), do: Transport.handle_error_response(response)

  @doc "Handles a Jira issue transition response (204 No Content)."
  def handle_transition_response({:ok, %{status: 204}}) do
    {:ok, %{transitioned: true}}
  end

  def handle_transition_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    {:ok, body}
  end

  def handle_transition_response(response), do: Transport.handle_error_response(response)

  @doc "Handles a Jira issue assign response (204 No Content)."
  def handle_assign_response({:ok, %{status: 204}}) do
    {:ok, %{assigned: true}}
  end

  def handle_assign_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    {:ok, Normalizer.normalize_issue(body)}
  end

  def handle_assign_response(response), do: Transport.handle_error_response(response)

  @doc "Handles a Jira issue comment create response."
  def handle_comment_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    case Normalizer.comment(body) do
      {:ok, comment} -> {:ok, Map.from_struct(comment) |> Map.drop([:metadata])}
      {:error, _} -> Transport.invalid_success_response("Jira comment response was invalid", body)
    end
  end

  def handle_comment_response(response), do: Transport.handle_error_response(response)

  @doc "Handles a generic Jira map response."
  def handle_map_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    {:ok, body}
  end

  def handle_map_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    Transport.invalid_success_response("Jira response was invalid", body)
  end

  def handle_map_response(response), do: Transport.handle_error_response(response)

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # A description that is not valid ADF fails explicitly. Payloads the struct
  # rejects return `:invalid`: issue reads keep the legacy `nil` for them,
  # search pages fail.
  defp read_issue(payload, requested_fields, message \\ @issue_invalid) do
    case Normalizer.issue(payload, requested_fields: requested_fields) do
      {:ok, issue} ->
        {:ok, Normalizer.issue_map(issue)}

      {:error, %Error.ValidationError{subject: :adf, reason: reason}} ->
        {:error,
         Error.provider(message,
           provider: :jira,
           reason: :invalid_response,
           delivery: :response_received,
           details: %{field: "description", adf_reason: reason}
         )}

      {:error, _invalid} ->
        :invalid
    end
  end

  defp read_issues(payloads, requested_fields, body) do
    payloads
    |> Enum.reduce_while({:ok, []}, fn payload, {:ok, issues} ->
      case read_issue(payload, requested_fields, @search_invalid) do
        {:ok, issue} -> {:cont, {:ok, [issue | issues]}}
        {:error, _error} = error -> {:halt, error}
        :invalid -> {:halt, invalid_search_page(body, "issues")}
      end
    end)
    |> case do
      {:ok, issues} -> {:ok, Enum.reverse(issues)}
      {:error, _error} = error -> error
    end
  end

  # Checks the page envelope of enhanced search before any issue is read.
  defp search_page(body) do
    issues = Data.get(body, "issues")
    is_last = Data.get(body, "isLast")
    token = Data.get(body, "nextPageToken")

    cond do
      not is_list(issues) ->
        invalid_search_page(body, "issues")

      not is_boolean(is_last) ->
        invalid_search_page(body, "isLast")

      not (is_nil(token) or (is_binary(token) and token != "")) ->
        invalid_search_page(body, "nextPageToken")

      is_last ->
        {:ok, %{issues: issues, next_page_token: nil, is_last: true}}

      is_nil(token) ->
        invalid_search_page(body, "nextPageToken")

      true ->
        {:ok, %{issues: issues, next_page_token: token, is_last: false}}
    end
  end

  # `Error.provider/2` keeps only a value-free summary of `body`.
  defp invalid_search_page(body, field) do
    {:error,
     Error.provider(@search_invalid,
       provider: :jira,
       reason: :invalid_response,
       delivery: :response_received,
       details: %{field: field, body: body}
     )}
  end

  defp normalize_project_map(payload) do
    case Normalizer.project(payload) do
      {:ok, struct} -> Map.from_struct(struct) |> Map.drop([:metadata])
      {:error, _} -> nil
    end
  end

  defp normalize_field_schema_map(payload) do
    case Normalizer.field_schema(payload) do
      {:ok, struct} -> Map.from_struct(struct) |> Map.drop([:metadata])
      {:error, _} -> nil
    end
  end
end
