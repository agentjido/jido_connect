defmodule Jido.Connect.Http do
  @moduledoc """
  Shared HTTP helpers for provider client modules.

  This is intentionally small. Provider clients still decide endpoint paths,
  request bodies, success payload normalization, and provider-specific API error
  bodies. Core only standardizes request construction and common provider error
  shaping.
  """

  alias Jido.Connect.{Data, Error, ProviderResponse}

  @user_agent "jido-connect"

  @spec bearer_request(String.t(), String.t(), keyword()) :: Req.Request.t()
  def bearer_request(base_url, access_token, opts \\ [])
      when is_binary(base_url) and is_binary(access_token) do
    Req.new(
      base_url: base_url,
      headers:
        [
          {"authorization", "Bearer #{access_token}"},
          {"user-agent", @user_agent}
        ] ++ Keyword.get(opts, :headers, [])
    )
    |> maybe_merge_req_options(Keyword.get(opts, :req_options, []))
  end

  @spec basic_request(String.t(), String.t(), String.t(), keyword()) :: Req.Request.t()
  def basic_request(base_url, username, password, opts \\ [])
      when is_binary(base_url) and is_binary(username) and is_binary(password) do
    encoded_credentials = Base.encode64("#{username}:#{password}")

    Req.new(
      base_url: base_url,
      headers:
        [
          {"authorization", "Basic #{encoded_credentials}"},
          {"user-agent", @user_agent}
        ] ++ Keyword.get(opts, :headers, [])
    )
    |> maybe_merge_req_options(Keyword.get(opts, :req_options, []))
  end

  @spec maybe_merge_req_options(Req.Request.t(), keyword()) :: Req.Request.t()
  def maybe_merge_req_options(request, []), do: request
  def maybe_merge_req_options(request, req_options), do: Req.merge(request, req_options)

  @doc "Adds query parameters to a URL without removing repeated keys."
  @spec url_with_query(String.t(), [{term(), term()}] | map()) :: String.t()
  def url_with_query(url, params) when is_binary(url) do
    case URI.encode_query(params) do
      "" ->
        url

      encoded_params ->
        uri = URI.parse(url)

        query =
          [uri.query, encoded_params]
          |> Enum.reject(&is_nil/1)
          |> Enum.join("&")

        %{uri | query: query}
        |> URI.to_string()
    end
  end

  @spec handle_map_response(term(), keyword()) :: {:ok, map()} | {:error, Error.error()}
  def handle_map_response({:ok, %{status: status, body: body}}, _opts)
      when status in 200..299 and is_map(body) do
    {:ok, body}
  end

  def handle_map_response(response, opts), do: provider_error(response, opts)

  @spec provider_error(term(), keyword()) :: {:error, Error.ProviderError.t()}
  def provider_error({:ok, %{status: status, body: body} = raw_response}, opts) do
    provider = Keyword.fetch!(opts, :provider)
    message = Keyword.get(opts, :message, "#{provider} API request failed")
    response = ProviderResponse.from_result!(provider, {:ok, raw_response}, opts)

    {:error,
     Error.provider(message,
       provider: provider,
       reason: Keyword.get(opts, :reason, :http_error),
       status: status,
       details: %{
         message: error_message(body),
         body: body,
         retry_after: response.retry_after,
         response: ProviderResponse.to_public_map(response)
       }
     )}
  end

  def provider_error({:error, reason}, opts) do
    provider = Keyword.fetch!(opts, :provider)
    message = Keyword.get(opts, :message, "#{provider} API request failed")
    response = ProviderResponse.from_result!(provider, {:error, reason}, opts)

    {:error,
     Error.provider(message,
       provider: provider,
       reason: :request_error,
       details: %{reason: reason, response: ProviderResponse.to_public_map(response)}
     )}
  end

  def provider_error(reason, opts) do
    provider = Keyword.fetch!(opts, :provider)
    message = Keyword.get(opts, :message, "#{provider} API request failed")
    response = ProviderResponse.from_result!(provider, reason, opts)

    {:error,
     Error.provider(message,
       provider: provider,
       reason: :unexpected_response,
       details: %{response: ProviderResponse.to_public_map(response)}
     )}
  end

  defp error_message(body) when is_map(body), do: Data.get(body, "message", body)

  defp error_message(body) when is_binary(body),
    do: "provider returned #{byte_size(body)} byte body"

  defp error_message(_body), do: "provider returned an error response"
end
