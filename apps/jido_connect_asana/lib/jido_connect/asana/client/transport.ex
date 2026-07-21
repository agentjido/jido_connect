defmodule Jido.Connect.Asana.Client.Transport do
  @moduledoc """
  Asana REST API transport configuration.

  Provides bearer-based request building for Asana personal access tokens
  and OAuth2 access tokens.
  """

  alias Jido.Connect.{Error, Provider.Transport}

  @doc "Builds an Asana API bearer request."
  @spec request(String.t(), keyword()) :: Req.Request.t()
  def request(access_token, opts \\ []) when is_binary(access_token) and is_list(opts) do
    Transport.bearer_request(
      Keyword.get(opts, :base_url, base_url()),
      access_token,
      headers: [
        {"accept", "application/json"},
        {"content-type", "application/json"}
      ],
      req_options:
        Application.get_env(:jido_connect_asana, :asana_req_options, [])
        |> Keyword.merge(Keyword.get(opts, :req_options, []))
    )
  end

  @doc "Returns the configured Asana API base URL."
  @spec base_url() :: String.t()
  def base_url do
    Application.get_env(:jido_connect_asana, :asana_api_base_url, "https://app.asana.com/api/1.0")
  end

  @doc "Normalizes an Asana provider error response."
  @spec handle_error_response(term(), keyword()) :: {:error, Error.ProviderError.t()}
  def handle_error_response(response, opts \\ [])

  def handle_error_response({:ok, %{status: status, body: body}}, opts)
      when is_integer(status) and is_map(body) do
    message = Keyword.get(opts, :message, "Asana API request failed")

    {:error,
     Error.provider(message,
       provider: :asana,
       reason: Keyword.get(opts, :reason, reason_from_status(status)),
       status: status,
       details: %{message: asana_error_message(body), body: body}
     )}
  end

  def handle_error_response(response, opts) do
    message = Keyword.get(opts, :message, "Asana API request failed")
    Transport.provider_error(response, provider: :asana, message: message)
  end

  @doc "Returns a sanitized provider error for malformed success payloads."
  @spec invalid_success_response(String.t(), term()) :: {:error, Error.ProviderError.t()}
  def invalid_success_response(message, body) do
    {:error,
     Error.provider(message,
       provider: :asana,
       reason: :invalid_response,
       details: %{body: body}
     )}
  end

  defp reason_from_status(401), do: :unauthorized
  defp reason_from_status(403), do: :forbidden
  defp reason_from_status(404), do: :not_found
  defp reason_from_status(429), do: :rate_limited
  defp reason_from_status(status) when status in 500..599, do: :server_error
  defp reason_from_status(_status), do: :http_error

  defp asana_error_message(%{"errors" => [%{"message" => msg} | _]}), do: msg
  defp asana_error_message(%{"error" => error}) when is_binary(error), do: error
  defp asana_error_message(%{"message" => message}) when is_binary(message), do: message
  defp asana_error_message(_body), do: "Asana API request failed"
end
