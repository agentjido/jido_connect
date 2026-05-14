defmodule Jido.Connect.Google.Drive.Client.Channels do
  @moduledoc "Google Drive notification channels API boundary."

  alias Jido.Connect.Google.Drive.Client.{Params, Response, Transport}

  def stop_channel(%{channel_id: channel_id, resource_id: resource_id} = params, access_token)
      when is_binary(channel_id) and is_binary(resource_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(
      url: "/v3/channels/stop",
      json: Params.stop_channel_body(params)
    )
    |> Response.handle_channel_stop_response(params)
  end
end
