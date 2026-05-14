defmodule Jido.Connect.Google.Calendar.Client.Calendars do
  @moduledoc "Google Calendar calendars API boundary."

  alias Jido.Connect.Google.Calendar.Client.{Params, Response, Transport}

  def get_calendar(%{calendar_id: calendar_id} = params, access_token)
      when is_binary(calendar_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url: "/v3/calendars/#{encode_id(calendar_id)}",
      params: Params.get_calendar_params(params)
    )
    |> Response.handle_calendar_response()
  end

  def create_calendar(params, access_token) when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(url: "/v3/calendars", json: Params.calendar_body(params))
    |> Response.handle_calendar_response()
  end

  def patch_calendar(%{calendar_id: calendar_id} = params, access_token)
      when is_binary(calendar_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.patch(
      url: "/v3/calendars/#{encode_id(calendar_id)}",
      json: Params.calendar_body(params)
    )
    |> Response.handle_calendar_response()
  end

  def update_calendar(%{calendar_id: calendar_id} = params, access_token)
      when is_binary(calendar_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.put(
      url: "/v3/calendars/#{encode_id(calendar_id)}",
      json: Params.calendar_body(params)
    )
    |> Response.handle_calendar_response()
  end

  def delete_calendar(%{calendar_id: calendar_id} = params, access_token)
      when is_binary(calendar_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.delete(url: "/v3/calendars/#{encode_id(calendar_id)}")
    |> Response.handle_calendar_delete_response(params)
  end

  def clear_calendar(%{calendar_id: calendar_id} = params, access_token)
      when is_binary(calendar_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(url: "/v3/calendars/#{encode_id(calendar_id)}/clear")
    |> Response.handle_calendar_clear_response(params)
  end

  defp encode_id(id), do: URI.encode(id, &URI.char_unreserved?/1)
end
