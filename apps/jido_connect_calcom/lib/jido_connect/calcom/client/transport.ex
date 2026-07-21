defmodule Jido.Connect.Calcom.Client.Transport do
  @moduledoc "Cal.com API transport boundary."

  alias Jido.Connect.{Error, Provider.Transport}

  @api_base_url "https://api.cal.com"

  @api_versions %{
    event_types: "2024-06-14",
    bookings_list: "2026-05-01",
    bookings_detail: "2026-02-25",
    webhooks: "2024-06-14"
  }

  @doc "Builds a Cal.com API bearer request."
  @spec api_request(String.t(), keyword()) :: Req.Request.t()
  def api_request(access_token, opts \\ []) when is_binary(access_token) and is_list(opts) do
    version = Keyword.get(opts, :cal_api_version)

    headers = [
      {"accept", "application/json"}
    ]

    headers =
      if version do
        [{"cal-api-version", version} | headers]
      else
        headers
      end

    Transport.bearer_request(
      Keyword.get(opts, :base_url, base_url()),
      access_token,
      headers: headers,
      req_options:
        Application.get_env(:jido_connect_calcom, :calcom_req_options, [])
        |> Keyword.merge(Keyword.get(opts, :req_options, []))
    )
  end

  @doc "Returns the configured Cal.com API base URL."
  @spec base_url() :: String.t()
  def base_url do
    Application.get_env(:jido_connect_calcom, :calcom_api_base_url, @api_base_url)
  end

  @doc "Returns the API version for the given endpoint group."
  @spec api_version(atom()) :: String.t()
  def api_version(group) when is_atom(group) do
    Map.fetch!(@api_versions, group)
  end

  @doc "Normalizes a Cal.com provider error response."
  @spec handle_error_response(term(), keyword()) :: {:error, Error.ProviderError.t()}
  def handle_error_response(response, opts \\ [])

  def handle_error_response({:ok, %{status: status, body: body}}, opts)
      when is_integer(status) and is_map(body) do
    message = Keyword.get(opts, :message, "Cal.com API request failed")

    {:error,
     Error.provider(message,
       provider: :calcom,
       reason: Keyword.get(opts, :reason, :http_error),
       status: status,
       details: %{message: calcom_error_message(body), body: body}
     )}
  end

  def handle_error_response(response, opts) do
    message = Keyword.get(opts, :message, "Cal.com API request failed")
    Transport.provider_error(response, provider: :calcom, message: message)
  end

  @doc "Returns a sanitized provider error for malformed success payloads."
  @spec invalid_success_response(String.t(), term()) :: {:error, Error.ProviderError.t()}
  def invalid_success_response(message, body) do
    {:error,
     Error.provider(message,
       provider: :calcom,
       reason: :invalid_response,
       details: %{body: body}
     )}
  end

  defp calcom_error_message(%{"error" => %{"message" => message}}) when is_binary(message),
    do: message

  defp calcom_error_message(%{"message" => message}) when is_binary(message), do: message
  defp calcom_error_message(_body), do: "Cal.com API request failed"
end
