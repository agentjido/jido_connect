defmodule Jido.Connect.Calendly.Client.Transport do
  @moduledoc "Calendly API transport boundary."

  alias Jido.Connect.{Error, Provider.Transport}

  @api_base_url "https://api.calendly.com"

  @doc "Builds a Calendly API bearer request."
  @spec api_request(String.t(), keyword()) :: Req.Request.t()
  def api_request(access_token, opts \\ [])
      when is_binary(access_token) and is_list(opts) do
    headers = [
      {"accept", "application/json"}
    ]

    Transport.bearer_request(
      Keyword.get(opts, :base_url, base_url()),
      access_token,
      headers: headers,
      req_options:
        Application.get_env(:jido_connect_calendly, :calendly_req_options, [])
        |> Keyword.merge(Keyword.get(opts, :req_options, []))
    )
  end

  @doc "Returns the configured Calendly API base URL."
  @spec base_url() :: String.t()
  def base_url do
    Application.get_env(:jido_connect_calendly, :calendly_api_base_url, @api_base_url)
  end

  @doc "Normalizes a Calendly provider error response."
  @spec handle_error_response(term(), keyword()) :: {:error, Error.ProviderError.t()}
  def handle_error_response(response, opts \\ [])

  def handle_error_response({:ok, %{status: status, body: body}}, opts)
      when is_integer(status) and is_map(body) do
    message = Keyword.get(opts, :message, "Calendly API request failed")

    {:error,
     Error.provider(message,
       provider: :calendly,
       reason: Keyword.get(opts, :reason, :http_error),
       status: status,
       details: %{message: calendly_error_message(body), body: body}
     )}
  end

  def handle_error_response(response, opts) do
    message = Keyword.get(opts, :message, "Calendly API request failed")
    Transport.provider_error(response, provider: :calendly, message: message)
  end

  @doc "Returns a sanitized provider error for malformed success payloads."
  @spec invalid_success_response(String.t(), term()) :: {:error, Error.ProviderError.t()}
  def invalid_success_response(message, body) do
    {:error,
     Error.provider(message,
       provider: :calendly,
       reason: :invalid_response,
       details: %{body: body}
     )}
  end

  defp calendly_error_message(%{"message" => message}) when is_binary(message), do: message
  defp calendly_error_message(%{"error" => message}) when is_binary(message), do: message
  defp calendly_error_message(_body), do: "Calendly API request failed"
end
