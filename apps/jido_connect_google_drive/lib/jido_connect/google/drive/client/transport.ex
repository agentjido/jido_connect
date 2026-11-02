defmodule Jido.Connect.Google.Drive.Client.Transport do
  @moduledoc "Google Drive API transport boundary."

  alias Jido.Connect.Google.Transport, as: GoogleTransport

  @base_url "https://www.googleapis.com/drive"

  def request(access_token) when is_binary(access_token) do
    GoogleTransport.request(access_token, base_url: base_url())
  end

  @doc """
  Builds a request for a file's stored bytes, as `files.get` with `alt=media`
  returns them.

  Req's body decoding is off, so a successful response keeps the bytes Drive
  sent, whatever their content type: a JSON file stays its text instead of
  becoming a map or a list. Google's errors are JSON, so a response step
  decodes the body of a non-2xx response with a JSON content type, and the
  error keeps Google's message. The step is attached here, before the live
  smoke recorder appends its own, so a recorded error holds the decoded body.
  """
  def media_request(access_token) when is_binary(access_token) do
    access_token
    |> request()
    |> Req.merge(decode_body: false)
    |> Req.Request.append_response_steps(google_drive_decode_error: &decode_error_body/1)
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

  # A body that is not JSON, or does not decode, stays raw.
  defp decode_error_body({request, %Req.Response{status: status, body: body} = response})
       when status not in 200..299 and is_binary(body) do
    with true <- json_content_type?(response),
         {:ok, decoded} <- Jason.decode(body) do
      {request, %{response | body: decoded}}
    else
      false -> {request, response}
      {:error, %Jason.DecodeError{}} -> {request, response}
    end
  end

  defp decode_error_body(request_response), do: request_response

  defp json_content_type?(response) do
    case Req.Response.get_header(response, "content-type") do
      [content_type | _rest] ->
        media_type =
          content_type
          |> String.split(";", parts: 2)
          |> hd()
          |> String.trim()
          |> String.downcase()

        media_type == "application/json" or String.ends_with?(media_type, "+json")

      [] ->
        false
    end
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
