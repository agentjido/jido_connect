defmodule Jido.Connect.Google.Calendar.Client.CalendarList do
  @moduledoc "Google Calendar calendarList API boundary."

  alias Jido.Connect.Google.Calendar.Client.{Params, Response, Transport}

  def list_calendars(params, access_token) when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(url: "/v3/users/me/calendarList", params: Params.list_calendars_params(params))
    |> Response.handle_calendar_list_response()
  end

  def watch_calendar_list(params, access_token) when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(url: "/v3/users/me/calendarList/watch", json: Params.watch_channel_body(params))
    |> Response.handle_channel_response()
  end
end
