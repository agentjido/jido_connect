defmodule Jido.Connect.Google.Calendar.Client.Response do
  @moduledoc "Google Calendar response handling."

  alias Jido.Connect.Data
  alias Jido.Connect.Google.Calendar.{Client.Transport, Normalizer}

  def handle_calendar_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    with {:ok, calendars} <-
           normalize_items(
             body,
             "items",
             &Normalizer.calendar/1,
             "Google Calendar calendar list response was invalid"
           ) do
      {:ok,
       %{
         calendars: calendars,
         next_page_token: Data.get(body, "nextPageToken"),
         next_sync_token: Data.get(body, "nextSyncToken")
       }
       |> Data.compact()}
    end
  end

  def handle_calendar_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Google Calendar calendar list response was invalid", body)
  end

  def handle_calendar_list_response(response), do: Transport.handle_error_response(response)

  def handle_event_list_response({:ok, %{status: status, body: body}}, params)
      when status in 200..299 and is_map(body) do
    normalizer = &Normalizer.event(&1, calendar_id: Data.get(params, :calendar_id))

    with {:ok, events} <-
           normalize_items(
             body,
             "items",
             normalizer,
             "Google Calendar event list response was invalid"
           ) do
      {:ok,
       %{
         events: events,
         next_page_token: Data.get(body, "nextPageToken"),
         next_sync_token: Data.get(body, "nextSyncToken")
       }
       |> Data.compact()}
    end
  end

  def handle_event_list_response({:ok, %{status: status, body: body}}, _params)
      when status in 200..299 do
    Transport.invalid_success_response("Google Calendar event list response was invalid", body)
  end

  def handle_event_list_response(response, _params), do: Transport.handle_error_response(response)

  def handle_event_response({:ok, %{status: status, body: body}}, params)
      when status in 200..299 and is_map(body) do
    normalize_one(
      body,
      &Normalizer.event(&1, calendar_id: Data.get(params, :calendar_id)),
      "Google Calendar event response was invalid"
    )
  end

  def handle_event_response({:ok, %{status: status, body: body}}, _params)
      when status in 200..299 do
    Transport.invalid_success_response("Google Calendar event response was invalid", body)
  end

  def handle_event_response(response, _params), do: Transport.handle_error_response(response)

  def handle_event_delete_response({:ok, %{status: status}}, params) when status in 200..299 do
    {:ok,
     %{
       calendar_id: Data.get(params, :calendar_id),
       event_id: Data.get(params, :event_id),
       deleted?: true
     }}
  end

  def handle_event_delete_response(response, _params),
    do: Transport.handle_error_response(response)

  def handle_channel_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    normalize_one(body, &Normalizer.channel/1, "Google Calendar channel response was invalid")
  end

  def handle_channel_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Google Calendar channel response was invalid", body)
  end

  def handle_channel_response(response), do: Transport.handle_error_response(response)

  def handle_channel_stop_response({:ok, %{status: status}}, params) when status in 200..299 do
    {:ok,
     %{
       channel_id: Data.get(params, :channel_id),
       resource_id: Data.get(params, :resource_id),
       stopped?: true
     }}
  end

  def handle_channel_stop_response(response, _params),
    do: Transport.handle_error_response(response)

  def handle_free_busy_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    normalize_one(body, &Normalizer.free_busy/1, "Google Calendar freebusy response was invalid")
  end

  def handle_free_busy_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Google Calendar freebusy response was invalid", body)
  end

  def handle_free_busy_response(response), do: Transport.handle_error_response(response)

  defp normalize_one(body, normalizer, message) do
    case normalizer.(body) do
      {:ok, item} -> {:ok, item}
      {:error, _error} -> Transport.invalid_success_response(message, body)
    end
  end

  defp normalize_items(body, key, normalizer, message) do
    case Data.get(body, key, []) do
      items when is_list(items) ->
        items
        |> Enum.reduce_while({:ok, []}, fn payload, {:ok, acc} ->
          case normalizer.(payload) do
            {:ok, item} -> {:cont, {:ok, [item | acc]}}
            {:error, _error} -> {:halt, Transport.invalid_success_response(message, body)}
          end
        end)
        |> case do
          {:ok, items} -> {:ok, Enum.reverse(items)}
          {:error, error} -> {:error, error}
        end

      _invalid ->
        Transport.invalid_success_response(message, body)
    end
  end
end
