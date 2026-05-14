defmodule Jido.Connect.Google.Analytics.Client.Transport do
  @moduledoc "Google Analytics API transport boundary."

  alias Jido.Connect.Google.Transport, as: GoogleTransport

  @data_base_url "https://analyticsdata.googleapis.com"
  @admin_base_url "https://analyticsadmin.googleapis.com"

  def data_request(access_token) when is_binary(access_token) do
    GoogleTransport.request(access_token, base_url: data_base_url())
  end

  def admin_request(access_token) when is_binary(access_token) do
    GoogleTransport.request(access_token, base_url: admin_base_url())
  end

  def data_base_url do
    Application.get_env(
      :jido_connect_google_analytics,
      :google_analytics_data_api_base_url,
      @data_base_url
    )
  end

  def admin_base_url do
    Application.get_env(
      :jido_connect_google_analytics,
      :google_analytics_admin_api_base_url,
      @admin_base_url
    )
  end

  defdelegate handle_error_response(response), to: GoogleTransport
  defdelegate invalid_success_response(message, body), to: GoogleTransport
end
