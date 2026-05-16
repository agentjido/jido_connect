defmodule Jido.Connect.Jira.Client.Response do
  @moduledoc "Jira Cloud REST success and error response handling."

  alias Jido.Connect.Data
  alias Jido.Connect.Jira.Client.{Normalizer, Transport}

  @doc "Handles a single Jira issue get response."
  def handle_issue_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    {:ok, Normalizer.normalize_issue(body)}
  end

  def handle_issue_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Jira issue response was invalid", body)
  end

  def handle_issue_response(response), do: Transport.handle_error_response(response)

  @doc "Handles a Jira issue search (JQL) response."
  def handle_issue_search_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    case Data.get(body, "issues") do
      issues when is_list(issues) ->
        {:ok,
         %{
           issues: Enum.map(issues, &Normalizer.normalize_issue/1),
           total: Data.get(body, "total"),
           start_at: Data.get(body, "startAt"),
           max_results: Data.get(body, "maxResults")
         }}

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

  @doc "Handles a generic Jira map response."
  def handle_map_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    {:ok, body}
  end

  def handle_map_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    Transport.invalid_success_response("Jira response was invalid", body)
  end

  def handle_map_response(response), do: Transport.handle_error_response(response)
end
