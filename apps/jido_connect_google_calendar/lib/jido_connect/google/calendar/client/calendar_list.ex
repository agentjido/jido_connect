defmodule Jido.Connect.Google.Calendar.Client.CalendarList do
  @moduledoc "Google Calendar calendarList API boundary."

  alias Jido.Connect.Google.Calendar.Client.{Params, Response, Transport}

  def list_calendars(params, access_token) when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(url: "/v3/users/me/calendarList", params: Params.list_calendars_params(params))
    |> Response.handle_calendar_list_response()
  end

  def get_calendar_list_entry(%{calendar_id: calendar_id} = params, access_token)
      when is_binary(calendar_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url: "/v3/users/me/calendarList/#{encode_id(calendar_id)}",
      params: Params.get_calendar_params(params)
    )
    |> Response.handle_calendar_response()
  end

  def create_calendar_list_entry(%{calendar_id: calendar_id} = params, access_token)
      when is_binary(calendar_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(
      url: "/v3/users/me/calendarList",
      params: Params.calendar_list_mutation_params(params),
      json: Params.calendar_list_entry_body(params)
    )
    |> Response.handle_calendar_response()
  end

  def patch_calendar_list_entry(%{calendar_id: calendar_id} = params, access_token)
      when is_binary(calendar_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.patch(
      url: "/v3/users/me/calendarList/#{encode_id(calendar_id)}",
      params: Params.calendar_list_mutation_params(params),
      json: Params.calendar_list_entry_body(params)
    )
    |> Response.handle_calendar_response()
  end

  def update_calendar_list_entry(%{calendar_id: calendar_id} = params, access_token)
      when is_binary(calendar_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.put(
      url: "/v3/users/me/calendarList/#{encode_id(calendar_id)}",
      params: Params.calendar_list_mutation_params(params),
      json: Params.calendar_list_entry_body(params)
    )
    |> Response.handle_calendar_response()
  end

  def delete_calendar_list_entry(%{calendar_id: calendar_id} = params, access_token)
      when is_binary(calendar_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.delete(url: "/v3/users/me/calendarList/#{encode_id(calendar_id)}")
    |> Response.handle_calendar_list_delete_response(params)
  end

  def watch_calendar_list(params, access_token) when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(url: "/v3/users/me/calendarList/watch", json: Params.watch_channel_body(params))
    |> Response.handle_channel_response()
  end

  defp encode_id(id), do: URI.encode(id, &URI.char_unreserved?/1)
end
