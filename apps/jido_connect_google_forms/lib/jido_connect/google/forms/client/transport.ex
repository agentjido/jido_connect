defmodule Jido.Connect.Google.Forms.Client.Transport do
  @moduledoc "Google Forms API transport boundary."

  alias Jido.Connect.Google.Transport, as: GoogleTransport

  @forms_base_url "https://forms.googleapis.com"

  def forms_request(access_token) when is_binary(access_token) do
    GoogleTransport.request(access_token, base_url: forms_base_url())
  end

  def forms_base_url do
    Application.get_env(
      :jido_connect_google_forms,
      :google_forms_api_base_url,
      @forms_base_url
    )
  end

  defdelegate handle_error_response(response), to: GoogleTransport
  defdelegate invalid_success_response(message, body), to: GoogleTransport
end
