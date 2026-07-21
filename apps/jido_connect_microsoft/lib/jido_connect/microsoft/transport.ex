defmodule Jido.Connect.Microsoft.Transport do
  @moduledoc """
  Microsoft Graph-specific HTTP transport configuration and error helpers.

  Product connector packages should use this module to build authenticated
  Graph requests and normalize provider errors. This module handles:

  - Bearer request construction with Microsoft Graph defaults.
  - Configurable base URL override via application environment.
  - Microsoft Graph error normalization from OData error envelopes.
  - Retry and rate-limit metadata extraction from Graph response headers.
  - Sanitized error shaping for malformed success payloads.

  ## Usage

      request = Transport.request(access_token)
      {:ok, response} = Transport.request(request, :get, params: [:"$top" => 25])

      # Error normalization
      {:error, error} = Transport.handle_error_response(response)

      # Retry metadata from a raw Req response
      meta = Transport.response_metadata({:ok, raw_response})
  """

  alias Jido.Connect.{Data, Error, Provider.Transport}

  @api_base_url "https://graph.microsoft.com/v1.0"

  # ---------------------------------------------------------------------------
  # Request construction
  # ---------------------------------------------------------------------------

  @doc "Builds a Microsoft Graph bearer request."
  @spec request(String.t(), keyword()) :: Req.Request.t()
  def request(access_token, opts \\ []) when is_binary(access_token) and is_list(opts) do
    Transport.bearer_request(
      Keyword.get(opts, :base_url, base_url()),
      access_token,
      headers: [
        {"accept", "application/json"}
      ],
      req_options:
        Application.get_env(:jido_connect_microsoft, :microsoft_req_options, [])
        |> Keyword.merge(Keyword.get(opts, :req_options, []))
    )
  end

  @doc "Executes a Microsoft Graph request through the shared provider transport."
  @spec request(Req.Request.t(), Transport.method(), keyword()) :: term()
  def request(%Req.Request{} = request, method, opts) do
    Transport.request(request, method, opts)
  end

  @doc "Returns the configured Microsoft Graph API base URL."
  @spec base_url() :: String.t()
  def base_url do
    Application.get_env(:jido_connect_microsoft, :microsoft_graph_base_url, @api_base_url)
  end

  # ---------------------------------------------------------------------------
  # Error normalization
  # ---------------------------------------------------------------------------

  @doc "Normalizes a Microsoft Graph provider error response."
  @spec handle_error_response(term(), keyword()) :: {:error, Error.ProviderError.t()}
  def handle_error_response(response, opts \\ [])

  def handle_error_response({:ok, %{status: status, body: body}}, opts)
      when is_integer(status) and is_map(body) do
    message = Keyword.get(opts, :message, "Microsoft Graph API request failed")

    {:error,
     Error.provider(message,
       provider: :microsoft,
       reason: Keyword.get(opts, :reason, :http_error),
       status: status,
       details: %{message: graph_error_message(body), body: body}
     )}
  end

  def handle_error_response(response, opts) do
    message = Keyword.get(opts, :message, "Microsoft Graph API request failed")
    Transport.provider_error(response, provider: :microsoft, message: message)
  end

  @doc "Returns a sanitized provider error for malformed success payloads."
  @spec invalid_success_response(String.t(), term()) :: {:error, Error.ProviderError.t()}
  def invalid_success_response(message, body) do
    {:error,
     Error.provider(message,
       provider: :microsoft,
       reason: :invalid_response,
       details: %{body: body}
     )}
  end

  # ---------------------------------------------------------------------------
  # Retry and rate-limit metadata
  # ---------------------------------------------------------------------------

  @doc """
  Extracts retry and rate-limit metadata from a Microsoft Graph response.

  Microsoft Graph signals throttling with HTTP 429 and a `Retry-After` header.
  Graph may also include `client-request-id` for diagnostics. This helper
  normalizes that metadata so connector packages and hosts can make informed
  retry decisions without parsing raw headers.

  ## Examples

      iex> Transport.response_metadata({:ok, %{status: 429, headers: headers}})
      %{rate_limited: true, retry_after: 30, request_id: "abc-123"}

      iex> Transport.response_metadata({:ok, %{status: 200, headers: headers}})
      %{rate_limited: false, request_id: "abc-123"}
  """
  @spec response_metadata({:ok, map()} | {:error, term()}) :: map()
  def response_metadata({:ok, %{status: status, headers: headers}})
      when is_integer(status) do
    normalized = normalize_headers(headers)

    %{
      rate_limited: status == 429,
      retry_after: parse_integer(Data.get(normalized, "retry-after")),
      request_id: Data.get(normalized, "client-request-id")
    }
    |> Data.compact()
  end

  def response_metadata({:error, _reason}) do
    %{rate_limited: false}
  end

  def response_metadata(_other) do
    %{}
  end

  @doc """
  Returns true when a Microsoft Graph response indicates rate limiting (HTTP 429).

  Connector packages can use this to decide whether to schedule a retry rather
  than propagating the error immediately.
  """
  @spec rate_limited?({:ok, map()} | term()) :: boolean()
  def rate_limited?({:ok, %{status: 429}}), do: true
  def rate_limited?({:ok, %{status: status}}) when is_integer(status), do: false
  def rate_limited?(_other), do: false

  @doc """
  Returns true when a Microsoft Graph error response is retryable.

  Retryable statuses: 429 (rate limit), 503 (service unavailable), 504 (gateway timeout).
  Also retryable on transport-level errors (timeouts, connection resets).
  """
  @spec retryable?(term()) :: boolean()
  def retryable?({:ok, %{status: status}}) when status in [429, 503, 504], do: true
  def retryable?({:ok, _response}), do: false
  def retryable?({:error, :timeout}), do: true
  def retryable?({:error, :connection_refused}), do: true
  def retryable?({:error, :closed}), do: true
  def retryable?(_other), do: false

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp graph_error_message(%{"error" => %{"message" => message}}) when is_binary(message),
    do: message

  defp graph_error_message(%{error: %{message: message}}) when is_binary(message), do: message
  defp graph_error_message(%{"error" => message}) when is_binary(message), do: message
  defp graph_error_message(%{error: message}) when is_binary(message), do: message
  defp graph_error_message(_body), do: "Microsoft Graph API request failed"

  defp normalize_headers(headers) when is_map(headers) do
    Map.new(headers, fn {key, value} ->
      {String.downcase(to_string(key)), header_value(value)}
    end)
  end

  defp normalize_headers(headers) when is_list(headers) do
    Map.new(headers, fn {key, value} ->
      {String.downcase(to_string(key)), header_value(value)}
    end)
  end

  defp normalize_headers(_headers), do: %{}

  defp header_value([value | _rest]), do: to_string(value)
  defp header_value(value), do: to_string(value)

  defp parse_integer(nil), do: nil

  defp parse_integer(value) do
    case Integer.parse(to_string(value)) do
      {integer, ""} -> integer
      _other -> nil
    end
  end
end
