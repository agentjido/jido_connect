defmodule Jido.Connect.Google.Calendar.Client.Acl do
  @moduledoc "Google Calendar ACL API boundary."

  alias Jido.Connect.Google.Calendar.Client.{Params, Response, Transport}

  def watch_acl(%{calendar_id: calendar_id} = params, access_token)
      when is_binary(calendar_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(
      url: "/v3/calendars/#{encode_id(calendar_id)}/acl/watch",
      json: Params.watch_channel_body(params)
    )
    |> Response.handle_channel_response()
  end

  defp encode_id(id), do: URI.encode(id, &URI.char_unreserved?/1)
end
