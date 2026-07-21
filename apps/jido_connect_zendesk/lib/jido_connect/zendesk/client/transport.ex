defmodule Jido.Connect.Zendesk.Client.Transport do
  @moduledoc """
  Zendesk REST transport boundary.

  Provides bearer-based request building for OAuth2 tokens.
  API token auth uses the `email/token:api_token` convention for
  Zendesk API token auth via HTTP Basic authentication.
  """

  alias Jido.Connect.{Error, Provider.Transport}

  @doc "Builds a Zendesk API bearer request for OAuth2 access tokens."
  @spec request(String.t(), keyword()) :: Req.Request.t()
  def request(access_token, opts \\ []) when is_binary(access_token) and is_list(opts) do
    Transport.bearer_request(
      Keyword.get(opts, :base_url, base_url()),
      access_token,
      headers: [
        {"accept", "application/json"}
      ],
      req_options:
        Application.get_env(:jido_connect_zendesk, :zendesk_req_options, [])
        |> Keyword.merge(Keyword.get(opts, :req_options, []))
    )
  end

  @doc """
  Builds a Zendesk API request with email/token basic auth.

  Uses the `email/token:api_token` convention for Zendesk API token auth.
  """
  @spec token_request(String.t(), String.t(), keyword()) :: Req.Request.t()
  def token_request(email, api_token, opts \\ [])
      when is_binary(email) and is_binary(api_token) and is_list(opts) do
    encoded = Base.encode64("#{email}/token:#{api_token}")

    Req.new(
      base_url: Keyword.get(opts, :base_url, base_url()),
      headers: [
        {"accept", "application/json"},
        {"authorization", "Basic #{encoded}"}
      ]
    )
    |> Req.merge(
      Application.get_env(:jido_connect_zendesk, :zendesk_req_options, [])
      |> Keyword.merge(Keyword.get(opts, :req_options, []))
    )
  end

  @doc "Returns the configured Zendesk API base URL."
  @spec base_url() :: String.t()
  def base_url do
    Application.get_env(
      :jido_connect_zendesk,
      :zendesk_api_base_url,
      "https://your-subdomain.zendesk.com"
    )
  end

  @doc "Normalizes a Zendesk provider error response."
  @spec handle_error_response(term(), keyword()) :: {:error, Error.ProviderError.t()}
  def handle_error_response(response, opts \\ [])

  def handle_error_response({:ok, %{status: status, body: body}}, opts)
      when is_integer(status) and is_map(body) do
    message = Keyword.get(opts, :message, "Zendesk API request failed")

    {:error,
     Error.provider(message,
       provider: :zendesk,
       reason: Keyword.get(opts, :reason, :http_error),
       status: status,
       details: %{message: zendesk_error_message(body), body: body}
     )}
  end

  def handle_error_response(response, opts) do
    message = Keyword.get(opts, :message, "Zendesk API request failed")
    Transport.provider_error(response, provider: :zendesk, message: message)
  end

  @doc "Returns a sanitized provider error for malformed success payloads."
  @spec invalid_success_response(String.t(), term()) :: {:error, Error.ProviderError.t()}
  def invalid_success_response(message, body) do
    {:error,
     Error.provider(message,
       provider: :zendesk,
       reason: :invalid_response,
       details: %{body: body}
     )}
  end

  defp zendesk_error_message(%{"error" => error}) when is_binary(error), do: error
  defp zendesk_error_message(%{"description" => desc}) when is_binary(desc), do: desc
  defp zendesk_error_message(%{"message" => message}) when is_binary(message), do: message
  defp zendesk_error_message(_body), do: "Zendesk API request failed"
end
