defmodule Jido.Connect.Google.Drive.Client.Changes do
  @moduledoc "Google Drive changes API boundary."

  alias Jido.Connect.Google.Drive.Client.{Params, Response, Transport}

  def get_start_page_token(params, access_token)
      when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url: "/v3/changes/startPageToken",
      params: Params.start_page_token_params(params)
    )
    |> Response.handle_start_page_token_response()
  end

  def list_changes(%{page_token: page_token} = params, access_token)
      when is_binary(page_token) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url: "/v3/changes",
      params: Params.list_changes_params(params)
    )
    |> Response.handle_change_list_response()
  end

  def watch_changes(%{page_token: page_token} = params, access_token)
      when is_binary(page_token) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(
      url: "/v3/changes/watch",
      params: Params.watch_changes_params(params),
      json: Params.watch_channel_body(params)
    )
    |> Response.handle_channel_response()
  end
end
