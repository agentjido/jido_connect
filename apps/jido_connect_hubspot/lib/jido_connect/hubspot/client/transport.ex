defmodule Jido.Connect.HubSpot.Client.Transport do
  @moduledoc "HubSpot API transport boundary."

  alias Jido.Connect.{Error, Provider.Transport}

  @api_base_url "https://api.hubapi.com"

  @doc "Builds a HubSpot API bearer request."
  @spec api_request(String.t(), keyword()) :: Req.Request.t()
  def api_request(access_token, opts \\ []) when is_binary(access_token) and is_list(opts) do
    Transport.bearer_request(
      Keyword.get(opts, :base_url, base_url()),
      access_token,
      headers: [{"accept", "application/json"}],
      req_options:
        Application.get_env(:jido_connect_hubspot, :hubspot_req_options, [])
        |> Keyword.merge(Keyword.get(opts, :req_options, []))
    )
  end

  @doc "Returns the configured HubSpot API base URL."
  @spec base_url() :: String.t()
  def base_url do
    Application.get_env(:jido_connect_hubspot, :hubspot_api_base_url, @api_base_url)
  end

  @doc "Normalizes a HubSpot provider error response."
  @spec handle_error_response(term(), keyword()) :: {:error, Error.ProviderError.t()}
  def handle_error_response(response, opts \\ [])

  def handle_error_response({:ok, %{status: status, body: body}}, opts)
      when is_integer(status) and is_map(body) do
    message = Keyword.get(opts, :message, "HubSpot API request failed")

    {:error,
     Error.provider(message,
       provider: :hubspot,
       reason: Keyword.get(opts, :reason, :http_error),
       status: status,
       details: %{message: hubspot_error_message(body), body: body}
     )}
  end

  def handle_error_response(response, opts) do
    message = Keyword.get(opts, :message, "HubSpot API request failed")
    Transport.provider_error(response, provider: :hubspot, message: message)
  end

  @doc "Returns a sanitized provider error for malformed success payloads."
  @spec invalid_success_response(String.t(), term()) :: {:error, Error.ProviderError.t()}
  def invalid_success_response(message, body) do
    {:error,
     Error.provider(message,
       provider: :hubspot,
       reason: :invalid_response,
       details: %{body: body}
     )}
  end

  defp hubspot_error_message(%{"message" => message}) when is_binary(message), do: message

  defp hubspot_error_message(%{"errors" => [%{"message" => message} | _]})
       when is_binary(message),
       do: message

  defp hubspot_error_message(_body), do: "HubSpot API request failed"
end
