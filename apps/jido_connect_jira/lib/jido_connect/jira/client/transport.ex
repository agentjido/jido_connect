defmodule Jido.Connect.Jira.Client.Transport do
  @moduledoc "Jira Atlassian Cloud REST transport boundary."

  alias Jido.Connect.{Error, Provider.Transport}

  @doc "Builds a Jira Cloud API bearer request."
  @spec request(String.t(), keyword()) :: Req.Request.t()
  def request(access_token, opts \\ []) when is_binary(access_token) and is_list(opts) do
    Transport.bearer_request(
      Keyword.get(opts, :base_url, base_url()),
      access_token,
      headers: [
        {"accept", "application/json"}
      ],
      req_options:
        Application.get_env(:jido_connect_jira, :jira_req_options, [])
        |> Keyword.merge(Keyword.get(opts, :req_options, []))
    )
  end

  @doc "Returns the configured Jira Cloud API base URL."
  @spec base_url() :: String.t()
  def base_url do
    Application.get_env(
      :jido_connect_jira,
      :jira_api_base_url,
      "https://your-domain.atlassian.net"
    )
  end

  @doc "Normalizes a Jira provider error response."
  @spec handle_error_response(term(), keyword()) :: {:error, Error.ProviderError.t()}
  def handle_error_response(response, opts \\ [])

  def handle_error_response({:ok, %{status: status, body: body}}, opts)
      when is_integer(status) and is_map(body) do
    message = Keyword.get(opts, :message, "Jira API request failed")

    {:error,
     Error.provider(message,
       provider: :jira,
       reason: Keyword.get(opts, :reason, :http_error),
       status: status,
       details: %{message: jira_error_message(body), body: body}
     )}
  end

  def handle_error_response(response, opts) do
    message = Keyword.get(opts, :message, "Jira API request failed")
    Transport.provider_error(response, provider: :jira, message: message)
  end

  @doc "Returns a sanitized provider error for malformed success payloads."
  @spec invalid_success_response(String.t(), term()) :: {:error, Error.ProviderError.t()}
  def invalid_success_response(message, body) do
    {:error,
     Error.provider(message,
       provider: :jira,
       reason: :invalid_response,
       details: %{body: body}
     )}
  end

  defp jira_error_message(%{"messages" => messages}) when is_list(messages) do
    messages
    |> Enum.map_join("; ", fn
      msg when is_binary(msg) -> msg
      %{"message" => m} -> m
      other -> inspect(other)
    end)
  end

  defp jira_error_message(%{"errorMessages" => messages}) when is_list(messages) do
    Enum.join(messages, "; ")
  end

  defp jira_error_message(%{"message" => message}) when is_binary(message), do: message
  defp jira_error_message(_body), do: "Jira API request failed"
end
