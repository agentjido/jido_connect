defmodule Jido.Connect.Jira.Client.IssueLifecycle do
  @moduledoc "Jira issue transition discovery and destructive lifecycle operations."

  alias Jido.Connect.Jira.Client.{Normalizer, Request, Transport}

  def list_transitions(issue_key, %Request{} = request) when is_binary(issue_key) do
    response =
      request
      |> Transport.request(req_options: [retry: false])
      |> Req.get(
        url: Request.url(request, "/rest/api/3/issue/#{path_segment(issue_key)}/transitions"),
        params: %{expand: "transitions.fields"}
      )

    case response do
      {:ok, %{status: status, body: body}} when status in 200..299 and is_map(body) ->
        normalize_transitions(body, issue_key)

      {:ok, %{status: status, body: body}} when status in 200..299 ->
        Transport.invalid_success_response(
          "Jira issue transition list response was invalid",
          body
        )

      other ->
        Transport.handle_error_response(other,
          message: "Jira issue transition list request failed"
        )
    end
  end

  def delete(issue_key, %Request{} = request) when is_binary(issue_key) do
    response =
      request
      |> Transport.request(req_options: [retry: false])
      |> Req.delete(url: Request.url(request, "/rest/api/3/issue/#{path_segment(issue_key)}"))

    case response do
      {:ok, %{status: status}} when status in 200..299 ->
        {:ok, %{issue_key: issue_key, deleted: true}}

      other ->
        Transport.handle_error_response(other,
          message: "Jira issue delete request failed",
          mutation?: true,
          provider_idempotency?: false
        )
    end
  end

  defp normalize_transitions(body, issue_key) do
    case Jido.Connect.Data.get(body, :transitions) do
      transitions when is_list(transitions) ->
        transitions
        |> Enum.reduce_while({:ok, []}, fn transition, {:ok, acc} ->
          case Normalizer.transition(transition) do
            {:ok, normalized} ->
              value = normalized |> Map.from_struct() |> Map.drop([:metadata])
              {:cont, {:ok, [value | acc]}}

            {:error, _reason} ->
              {:halt, :error}
          end
        end)
        |> case do
          {:ok, values} ->
            values = Enum.reverse(values)
            {:ok, %{issue_key: issue_key, transitions: values, count: length(values)}}

          :error ->
            Transport.invalid_success_response(
              "Jira issue transition list response was invalid",
              body
            )
        end

      _other ->
        Transport.invalid_success_response(
          "Jira issue transition list response was invalid",
          body
        )
    end
  end

  defp path_segment(value), do: URI.encode(value, &URI.char_unreserved?/1)
end
