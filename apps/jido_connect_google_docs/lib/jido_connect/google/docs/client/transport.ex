defmodule Jido.Connect.Google.Docs.Client.Transport do
  @moduledoc "Google Docs API transport boundary."

  alias Jido.Connect.Google.Transport, as: GoogleTransport

  @docs_base_url "https://docs.googleapis.com"

  def docs_request(access_token) when is_binary(access_token) do
    GoogleTransport.request(access_token, base_url: docs_base_url())
  end

  def docs_base_url do
    Application.get_env(
      :jido_connect_google_docs,
      :google_docs_api_base_url,
      @docs_base_url
    )
  end

  defdelegate handle_error_response(response), to: GoogleTransport
  defdelegate invalid_success_response(message, body), to: GoogleTransport
end
