defmodule Jido.Connect.Notion.Client.Transport do
  @moduledoc "Notion REST API transport configuration."

  alias Jido.Connect.Provider.Transport

  @notion_version "2022-06-28"

  @spec request(String.t()) :: Req.Request.t()
  def request(access_token) when is_binary(access_token) do
    Transport.bearer_request(
      base_url(),
      access_token,
      headers: [
        {"notion-version", @notion_version},
        {"content-type", "application/json"}
      ],
      req_options: Application.get_env(:jido_connect_notion, :notion_req_options, [])
    )
  end

  @spec base_url() :: String.t()
  def base_url do
    Application.get_env(:jido_connect_notion, :notion_api_base_url, "https://api.notion.com/v1")
  end

  @spec handle_error_response(term()) :: {:error, Jido.Connect.Error.ProviderError.t()}
  def handle_error_response(response),
    do:
      Transport.provider_error(response,
        provider: :notion,
        message: "Notion API request failed"
      )

  @spec invalid_success_response(String.t(), term()) ::
          {:error, Jido.Connect.Error.ProviderError.t()}
  def invalid_success_response(message, body) do
    {:error,
     Jido.Connect.Error.provider(message,
       provider: :notion,
       reason: :invalid_response,
       details: %{body: body}
     )}
  end
end
