defmodule Jido.Connect.Google.Drive.Client.Transport do
  @moduledoc "Google Drive API transport boundary."

  alias Jido.Connect.Google.Transport, as: GoogleTransport

  @base_url "https://www.googleapis.com/drive"

  def request(access_token) when is_binary(access_token) do
    GoogleTransport.request(access_token, base_url: base_url())
  end

  def upload_request(access_token) when is_binary(access_token) do
    GoogleTransport.request(access_token, base_url: upload_base_url())
  end

  def base_url do
    Application.get_env(:jido_connect_google_drive, :google_drive_api_base_url, @base_url)
  end

  def upload_base_url do
    base_url()
    |> URI.parse()
    |> preserve_prefix_before_drive_path()
    |> URI.to_string()
  end

  defp preserve_prefix_before_drive_path(%URI{path: path} = uri) when is_binary(path) do
    path =
      path
      |> String.trim_trailing("/")
      |> String.replace_suffix("/drive", "")

    %{uri | path: empty_path_to_nil(path)}
  end

  defp preserve_prefix_before_drive_path(uri), do: uri

  defp empty_path_to_nil(""), do: nil
  defp empty_path_to_nil(path), do: path

  defdelegate handle_error_response(response), to: GoogleTransport
  defdelegate invalid_success_response(message, body), to: GoogleTransport
end
