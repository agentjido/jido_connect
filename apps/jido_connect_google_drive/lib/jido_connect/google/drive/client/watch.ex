defmodule Jido.Connect.Google.Drive.Client.Watch do
  @moduledoc "Google Drive watch API boundary."

  alias Jido.Connect.Google.Drive.Client.{Params, Response, Transport}

  def watch_file(%{file_id: file_id} = params, access_token)
      when is_binary(file_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(
      url: "/v3/files/#{encode_id(file_id)}/watch",
      params: Params.watch_file_params(params),
      json: Params.channel_body(params)
    )
    |> Response.handle_channel_response()
  end

  def watch_changes(%{page_token: page_token} = params, access_token)
      when is_binary(page_token) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(
      url: "/v3/changes/watch",
      params: Params.watch_changes_params(params),
      json: Params.channel_body(params)
    )
    |> Response.handle_channel_response()
  end

  defp encode_id(value), do: URI.encode(value, &URI.char_unreserved?/1)
end
