defmodule Jido.Connect.Google.Transport do
  @moduledoc "Google-specific HTTP transport configuration."

  alias Jido.Connect.{Error, Provider.Transport}

  @api_base_url "https://www.googleapis.com"

  @doc "Builds a Google API bearer request."
  @spec request(String.t(), keyword()) :: Req.Request.t()
  def request(access_token, opts \\ []) when is_binary(access_token) and is_list(opts) do
    Transport.bearer_request(
      Keyword.get(opts, :base_url, base_url()),
      access_token,
      headers: [
        {"accept", "application/json"}
      ],
      req_options:
        Application.get_env(:jido_connect_google, :google_req_options, [])
        |> Keyword.merge(Keyword.get(opts, :req_options, []))
    )
  end

  @doc "Executes a Google API request through the shared provider transport."
  @spec request(Req.Request.t(), Transport.method(), keyword()) :: term()
  def request(%Req.Request{} = request, method, opts) do
    Transport.request(request, method, opts)
  end

  @doc "Returns the configured Google API base URL."
  @spec base_url() :: String.t()
  def base_url do
    Application.get_env(:jido_connect_google, :google_api_base_url, @api_base_url)
  end

  @doc "Normalizes a Google provider error response."
  @spec handle_error_response(term(), keyword()) :: {:error, Error.ProviderError.t()}
  def handle_error_response(response, opts \\ [])

  def handle_error_response({:ok, %{status: status, body: body}} = response, opts)
      when is_integer(status) and is_map(body) do
    message = Keyword.get(opts, :message, "Google API request failed")

    Transport.provider_error(
      response,
      Keyword.merge(opts,
        provider: :google,
        message: message,
        reason: Keyword.get(opts, :reason, :http_error),
        detail_message: google_error_message(body)
      )
    )
  end

  def handle_error_response(response, opts) do
    message = Keyword.get(opts, :message, "Google API request failed")
    Transport.provider_error(response, Keyword.merge(opts, provider: :google, message: message))
  end

  @doc "Returns a sanitized provider error for malformed success payloads."
  @spec invalid_success_response(String.t(), term()) :: {:error, Error.ProviderError.t()}
  def invalid_success_response(message, body) do
    {:error,
     Error.provider(message,
       provider: :google,
       reason: :invalid_response,
       details: %{body: body}
     )}
  end

  defp google_error_message(%{"error" => %{"message" => message}}) when is_binary(message),
    do: message

  defp google_error_message(%{error: %{message: message}}) when is_binary(message), do: message
  defp google_error_message(%{"error" => message}) when is_binary(message), do: message
  defp google_error_message(%{error: message}) when is_binary(message), do: message
  defp google_error_message(_body), do: "Google API request failed"
end
