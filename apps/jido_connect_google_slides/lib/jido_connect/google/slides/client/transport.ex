defmodule Jido.Connect.Google.Slides.Client.Transport do
  @moduledoc "Google Slides API transport boundary."

  alias Jido.Connect.Google.Transport, as: GoogleTransport

  @slides_base_url "https://slides.googleapis.com"

  def slides_request(access_token) when is_binary(access_token) do
    GoogleTransport.request(access_token, base_url: slides_base_url())
  end

  def slides_base_url do
    Application.get_env(
      :jido_connect_google_slides,
      :google_slides_api_base_url,
      @slides_base_url
    )
  end

  defdelegate handle_error_response(response), to: GoogleTransport
  defdelegate invalid_success_response(message, body), to: GoogleTransport
end
