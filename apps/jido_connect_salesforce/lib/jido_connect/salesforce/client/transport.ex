defmodule Jido.Connect.Salesforce.Client.Transport do
  @moduledoc """
  Salesforce REST API transport boundary.

  Salesforce REST APIs are scoped to an org-specific instance URL
  (e.g., `https://myorg.my.salesforce.com`). The instance URL is extracted
  from credentials and used as the base URL for all requests.

  The default API version is `60.0`, configurable via application env.
  """

  alias Jido.Connect.{Error, Provider.Transport}

  @default_api_version "60.0"
  @default_instance_url "https://login.salesforce.com"

  @doc "Returns the configured Salesforce API version."
  @spec api_version() :: String.t()
  def api_version do
    Application.get_env(:jido_connect_salesforce, :salesforce_api_version, @default_api_version)
  end

  @doc "Returns the default instance URL used when none is available in credentials."
  @spec default_instance_url() :: String.t()
  def default_instance_url do
    Application.get_env(:jido_connect_salesforce, :salesforce_instance_url, @default_instance_url)
  end

  @doc "Builds the Salesforce REST API base path for the configured API version."
  @spec rest_base(String.t()) :: String.t()
  def rest_base(instance_url) when is_binary(instance_url) do
    "#{String.trim_trailing(instance_url, "/")}/services/data/v#{api_version()}"
  end

  @doc "Builds a Salesforce REST API bearer request."
  @spec api_request(String.t(), String.t(), keyword()) :: Req.Request.t()
  def api_request(instance_url, access_token, opts \\ [])
      when is_binary(instance_url) and is_binary(access_token) and is_list(opts) do
    base = rest_base(instance_url)

    Transport.bearer_request(
      base,
      access_token,
      headers: [{"accept", "application/json"}],
      req_options:
        Application.get_env(:jido_connect_salesforce, :salesforce_req_options, [])
        |> Keyword.merge(Keyword.get(opts, :req_options, []))
    )
  end

  @doc "Normalizes a Salesforce provider error response."
  @spec handle_error_response(term(), keyword()) :: {:error, Error.ProviderError.t()}
  def handle_error_response(response, opts \\ [])

  def handle_error_response({:ok, %{status: status, body: body}}, opts)
      when is_integer(status) and is_map(body) do
    message = Keyword.get(opts, :message, "Salesforce API request failed")

    {:error,
     Error.provider(message,
       provider: :salesforce,
       reason: Keyword.get(opts, :reason, :http_error),
       status: status,
       details: %{message: salesforce_error_message(body), body: body}
     )}
  end

  def handle_error_response(response, opts) do
    message = Keyword.get(opts, :message, "Salesforce API request failed")
    Transport.provider_error(response, provider: :salesforce, message: message)
  end

  @doc "Returns a sanitized provider error for malformed success payloads."
  @spec invalid_success_response(String.t(), term()) :: {:error, Error.ProviderError.t()}
  def invalid_success_response(message, body) do
    {:error,
     Error.provider(message,
       provider: :salesforce,
       reason: :invalid_response,
       details: %{body: body}
     )}
  end

  defp salesforce_error_message(%{"message" => message}) when is_binary(message), do: message

  defp salesforce_error_message(%{error: error, error_description: description})
       when is_binary(error) and is_binary(description),
       do: "#{error}: #{description}"

  defp salesforce_error_message(%{"error" => error, "error_description" => description})
       when is_binary(error) and is_binary(description),
       do: "#{error}: #{description}"

  defp salesforce_error_message(_body), do: "Salesforce API request failed"
end
