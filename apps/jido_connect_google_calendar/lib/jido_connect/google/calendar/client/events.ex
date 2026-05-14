defmodule Jido.Connect.Google.Calendar.Client.Events do
  @moduledoc "Google Calendar events API boundary."

  alias Jido.Connect.Google.Calendar.Client.{Params, Response, Transport}

  def list_events(%{calendar_id: calendar_id} = params, access_token)
      when is_binary(calendar_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url: "/v3/calendars/#{encode_id(calendar_id)}/events",
      params: Params.list_events_params(params)
    )
    |> Response.handle_event_list_response(params)
  end

  def watch_events(%{calendar_id: calendar_id} = params, access_token)
      when is_binary(calendar_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(
      url: "/v3/calendars/#{encode_id(calendar_id)}/events/watch",
      params: Params.watch_events_params(params),
      json: Params.watch_channel_body(params)
    )
    |> Response.handle_channel_response()
  end

  def get_event(%{calendar_id: calendar_id, event_id: event_id} = params, access_token)
      when is_binary(calendar_id) and is_binary(event_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url: "/v3/calendars/#{encode_id(calendar_id)}/events/#{encode_id(event_id)}",
      params: Params.get_event_params(params)
    )
    |> Response.handle_event_response(params)
  end

  def create_event(%{calendar_id: calendar_id} = params, access_token)
      when is_binary(calendar_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(
      url: "/v3/calendars/#{encode_id(calendar_id)}/events",
      params: Params.event_mutation_params(params),
      json: Params.event_create_body(params)
    )
    |> Response.handle_event_response(params)
  end

  def update_event(%{calendar_id: calendar_id, event_id: event_id} = params, access_token)
      when is_binary(calendar_id) and is_binary(event_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.patch(
      url: "/v3/calendars/#{encode_id(calendar_id)}/events/#{encode_id(event_id)}",
      params: Params.event_mutation_params(params),
      json: Params.event_update_body(params)
    )
    |> Response.handle_event_response(params)
  end

  def delete_event(%{calendar_id: calendar_id, event_id: event_id} = params, access_token)
      when is_binary(calendar_id) and is_binary(event_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.delete(
      url: "/v3/calendars/#{encode_id(calendar_id)}/events/#{encode_id(event_id)}",
      params: Params.delete_event_params(params)
    )
    |> Response.handle_event_delete_response(params)
  end

  defp encode_id(id), do: URI.encode(id, &URI.char_unreserved?/1)
end
