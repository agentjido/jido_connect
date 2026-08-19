defmodule Jido.Connect.Jira.Client.Transport do
  @moduledoc "Jira Atlassian Cloud REST transport boundary."

  alias Jido.Connect.{Error, Provider.Transport}
  alias Jido.Connect.Jira.Client.Request

  @doc "Builds a Basic-auth or OAuth Bearer request for one Jira connection."
  @spec request(Request.t(), keyword()) :: Req.Request.t()
  def request(%Request{} = request, opts \\ []) when is_list(opts) do
    common_opts = [
      headers: [{"accept", "application/json"}],
      req_options:
        Application.get_env(:jido_connect_jira, :jira_req_options, [])
        |> Keyword.merge(Keyword.get(opts, :req_options, []))
    ]

    case request.auth_profile do
      :api_token ->
        Transport.basic_request(
          request.endpoint,
          Request.credential(request, :email),
          Request.credential(request, :api_token),
          common_opts
        )

      :oauth2_user ->
        Transport.bearer_request(
          request.endpoint,
          Request.credential(request, :access_token),
          common_opts
        )
    end
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
       delivery: :rejected,
       mutation?: Keyword.get(opts, :mutation?, false),
       provider_idempotency?: Keyword.get(opts, :provider_idempotency?, false),
       details: %{message: jira_error_message(body), body: body}
     )}
  end

  def handle_error_response(response, opts) do
    message = Keyword.get(opts, :message, "Jira API request failed")

    Transport.provider_error(response,
      provider: :jira,
      message: message,
      mutation?: Keyword.get(opts, :mutation?, false),
      provider_idempotency?: Keyword.get(opts, :provider_idempotency?, false)
    )
  end

  @doc "Returns a sanitized provider error for malformed success payloads."
  @spec invalid_success_response(String.t(), term(), keyword()) ::
          {:error, Error.ProviderError.t()}
  def invalid_success_response(message, body, opts \\ []) do
    {:error,
     Error.provider(message,
       provider: :jira,
       reason: :invalid_response,
       delivery: :response_received,
       mutation?: Keyword.get(opts, :mutation?, false),
       provider_idempotency?: Keyword.get(opts, :provider_idempotency?, false),
       details: %{body: body}
     )}
  end

  defp jira_error_message(%{"messages" => messages}) when is_list(messages) do
    Enum.map_join(messages, "; ", fn
      message when is_binary(message) -> message
      %{"message" => message} -> message
      other -> inspect(other)
    end)
  end

  defp jira_error_message(%{"errorMessages" => messages}) when is_list(messages),
    do: Enum.join(messages, "; ")

  defp jira_error_message(%{"message" => message}) when is_binary(message), do: message
  defp jira_error_message(_body), do: "Jira API request failed"
end
