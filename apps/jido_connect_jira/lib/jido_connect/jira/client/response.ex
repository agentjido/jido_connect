defmodule Jido.Connect.Jira.Client.Response do
  @moduledoc "Jira Cloud REST success and error response handling."

  alias Jido.Connect.{Data, Error}
  alias Jido.Connect.Jira.Client.{Normalizer, Transport}

  @doc """
  Handles a single Jira issue get response.

  A description that is not valid ADF fails the read with an
  `:invalid_response` error whose details name the field and the projection
  reason, without the issue content.
  """
  def handle_issue_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    read_issue(body, "Jira issue response was invalid")
  end

  def handle_issue_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Jira issue response was invalid", body)
  end

  def handle_issue_response(response), do: Transport.handle_error_response(response)

  @doc """
  Handles a Jira issue search (JQL) response.

  An issue whose description is not valid ADF fails the whole page, as in
  `handle_issue_response/1`.
  """
  def handle_issue_search_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    with issues when is_list(issues) <- Data.get(body, "issues"),
         {:ok, issues} <- read_issues(issues, "Jira issue search response was invalid") do
      {:ok,
       %{
         issues: issues,
         total: Data.get(body, "total"),
         start_at: Data.get(body, "startAt"),
         max_results: Data.get(body, "maxResults"),
         is_last: Data.get(body, "isLast")
       }}
    else
      {:error, _error} = error ->
        error

      _other ->
        Transport.invalid_success_response("Jira issue search response was invalid", body)
    end
  end

  def handle_issue_search_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Jira issue search response was invalid", body)
  end

  def handle_issue_search_response(response), do: Transport.handle_error_response(response)

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

  # Issue reads keep the legacy `nil` for payloads the struct rejects, but a
  # description that is not valid ADF fails explicitly.
  defp read_issue(payload, message) do
    case Normalizer.issue(payload) do
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
        {:ok, nil}
    end
  end

  defp read_issues(payloads, message) do
    payloads
    |> Enum.reduce_while({:ok, []}, fn payload, {:ok, issues} ->
      case read_issue(payload, message) do
        {:ok, issue} -> {:cont, {:ok, [issue | issues]}}
        {:error, _error} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, issues} -> {:ok, Enum.reverse(issues)}
      {:error, _error} = error -> error
    end
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
