defmodule Jido.Connect.Google.Tasks.Client.Transport do
  @moduledoc "Google Tasks API transport boundary."

  alias Jido.Connect.Google.Transport, as: GoogleTransport

  @tasks_base_url "https://tasks.googleapis.com"

  def tasks_request(access_token) when is_binary(access_token) do
    GoogleTransport.request(access_token, base_url: tasks_base_url())
  end

  def tasks_base_url do
    Application.get_env(
      :jido_connect_google_tasks,
      :google_tasks_api_base_url,
      @tasks_base_url
    )
  end

  defdelegate handle_error_response(response), to: GoogleTransport
  defdelegate invalid_success_response(message, body), to: GoogleTransport
end
