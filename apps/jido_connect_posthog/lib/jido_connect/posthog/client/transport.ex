defmodule Jido.Connect.PostHog.Client.Transport do
  @moduledoc "PostHog REST API transport boundary."

  alias Jido.Connect.{Error, Provider.Transport}

  @default_base_url "https://app.posthog.com"

  @doc "Builds a PostHog API bearer request."
  @spec request(String.t(), keyword()) :: Req.Request.t()
  def request(api_key, opts \\ []) when is_binary(api_key) and is_list(opts) do
    Transport.bearer_request(
      Keyword.get(opts, :base_url, base_url()),
      api_key,
      headers: [
        {"accept", "application/json"},
        {"content-type", "application/json"}
      ],
      req_options:
        Application.get_env(:jido_connect_posthog, :posthog_req_options, [])
        |> Keyword.merge(Keyword.get(opts, :req_options, []))
    )
  end

  @doc "Returns the configured PostHog API base URL."
  @spec base_url() :: String.t()
  def base_url do
    Application.get_env(
      :jido_connect_posthog,
      :posthog_api_base_url,
      @default_base_url
    )
  end

  @doc "Normalizes a PostHog provider error response."
  @spec handle_error_response(term(), keyword()) :: {:error, Error.ProviderError.t()}
  def handle_error_response(response, opts \\ [])

  def handle_error_response({:ok, %{status: status, body: body}}, opts)
      when is_integer(status) and is_map(body) do
    message = Keyword.get(opts, :message, "PostHog API request failed")

    {:error,
     Error.provider(message,
       provider: :posthog,
       reason: Keyword.get(opts, :reason, :http_error),
       status: status,
       details: %{message: posthog_error_message(body), body: body}
     )}
  end

  def handle_error_response(response, opts) do
    message = Keyword.get(opts, :message, "PostHog API request failed")
    Transport.provider_error(response, provider: :posthog, message: message)
  end

  @doc "Returns a sanitized provider error for malformed success payloads."
  @spec invalid_success_response(String.t(), term()) :: {:error, Error.ProviderError.t()}
  def invalid_success_response(message, body) do
    {:error,
     Error.provider(message,
       provider: :posthog,
       reason: :invalid_response,
       details: %{body: body}
     )}
  end

  defp posthog_error_message(%{"detail" => detail}) when is_binary(detail), do: detail
  defp posthog_error_message(%{"error" => error}) when is_binary(error), do: error

  defp posthog_error_message(%{"type" => type, "message" => message})
       when is_binary(type) and is_binary(message),
       do: "#{type}: #{message}"

  defp posthog_error_message(_body), do: "PostHog API request failed"
end
