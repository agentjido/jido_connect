defmodule Jido.Connect.Google.Calendar.Client.Settings do
  @moduledoc "Google Calendar settings API boundary."

  alias Jido.Connect.Google.Calendar.Client.{Params, Response, Transport}

  def watch_settings(params, access_token) when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(url: "/v3/users/me/settings/watch", json: Params.watch_channel_body(params))
    |> Response.handle_channel_response()
  end
end
