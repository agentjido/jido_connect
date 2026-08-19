defmodule Jido.Connect.Slack.Client.Transport do
  @moduledoc "Slack-specific Web API transport configuration."

  alias Jido.Connect.{Error, Provider.Transport}
  alias Jido.Connect.Slack.Client.Response

  @spec request(String.t()) :: Req.Request.t()
  def request(access_token) when is_binary(access_token) do
    req_options =
      :jido_connect_slack
      |> Application.get_env(:slack_req_options, [])
      |> Keyword.put(:retry, false)

    Transport.bearer_request(
      base_url(),
      access_token,
      req_options: req_options
    )
  end

  @spec base_url() :: String.t()
  def base_url do
    Application.get_env(:jido_connect_slack, :slack_api_base_url, "https://slack.com/api")
  end

  @spec post_file_content(term(), term()) :: {:ok, term()} | {:error, Error.error()}
  def post_file_content(upload_url, content) when is_binary(upload_url) and is_binary(content) do
    Req.new(url: upload_url, headers: [{"content-type", "application/octet-stream"}])
    |> Req.merge(Application.get_env(:jido_connect_slack, :slack_upload_req_options, []))
    |> Req.post(body: content)
    |> Response.handle_file_content_response()
  end

  def post_file_content(_upload_url, _content) do
    {:error,
     Error.provider("Slack upload URL response was invalid",
       provider: :slack,
       reason: :invalid_response
     )}
  end

  @spec provider_error(term(), keyword()) :: {:error, Error.ProviderError.t()}
  def provider_error(response, opts), do: Transport.provider_error(response, opts)

  @spec invalid_success_response(String.t(), term()) :: {:error, Error.ProviderError.t()}
  def invalid_success_response(message, body) do
    {:error,
     Error.provider(message,
       provider: :slack,
       reason: :invalid_response,
       details: %{body: body}
     )}
  end
end
