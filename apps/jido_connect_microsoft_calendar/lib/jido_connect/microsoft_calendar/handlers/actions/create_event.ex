defmodule Jido.Connect.MicrosoftCalendar.Handlers.Actions.CreateEvent do
  @moduledoc false

  alias Jido.Connect.Microsoft.Transport
  alias Jido.Connect.MicrosoftCalendar.Normalizer

  @doc """
  Creates a new event in a Microsoft Calendar via Microsoft Graph.

  POST /me/calendar/events or POST /me/calendars/{calendar_id}/events
  with a JSON body containing subject, body, start/end times, location,
  and attendees.
  """
  def run(input, %{credentials: %{access_token: access_token}})
      when is_binary(access_token) do
    body = build_event_body(input)
    request = Transport.request(access_token)
    url = events_url(Map.get(input, :calendar_id))

    case Transport.request(request, :post, url: url, json: body) do
      {:ok, %{status: 201, body: response_body}} when is_map(response_body) ->
        normalize_event(response_body)

      {:ok, %{status: 200, body: response_body}} when is_map(response_body) ->
        normalize_event(response_body)

      {:ok, response} ->
        Transport.handle_error_response({:ok, response},
          message: "Failed to create Microsoft calendar event"
        )

      {:error, _reason} = error ->
        Transport.handle_error_response(error,
          message: "Failed to create Microsoft calendar event"
        )
    end
  end

  def run(_input, _context), do: {:error, :missing_access_token}

  defp events_url(nil), do: "/me/calendar/events"
  defp events_url(calendar_id), do: "/me/calendars/#{calendar_id}/events"

  defp build_event_body(input) do
    time_zone = Map.get(input, :time_zone, "UTC")

    body = %{
      "subject" => Map.get(input, :subject, ""),
      "start" => %{
        "dateTime" => Map.get(input, :start_date_time),
        "timeZone" => time_zone
      },
      "end" => %{
        "dateTime" => Map.get(input, :end_date_time),
        "timeZone" => time_zone
      }
    }

    body =
      case Map.get(input, :body) do
        nil ->
          body

        content ->
          content_type =
            case Map.get(input, :content_type, "text") do
              "html" -> "html"
              _ -> "text"
            end

          Map.put(body, "body", %{"contentType" => content_type, "content" => content})
      end

    body =
      case Map.get(input, :location) do
        nil -> body
        loc -> Map.put(body, "location", %{"displayName" => loc})
      end

    body =
      case Map.get(input, :attendees) do
        nil -> body
        [] -> body
        attendees -> Map.put(body, "attendees", format_attendees(attendees))
      end

    body =
      case Map.get(input, :is_all_day) do
        nil -> body
        val -> Map.put(body, "isAllDay", val)
      end

    body =
      case Map.get(input, :sensitivity) do
        nil -> body
        val -> Map.put(body, "sensitivity", val)
      end

    body =
      case Map.get(input, :show_as) do
        nil -> body
        val -> Map.put(body, "showAs", val)
      end

    body =
      case Map.get(input, :recurrence) do
        nil -> body
        rec -> Map.put(body, "recurrence", rec)
      end

    body
  end

  defp format_attendees(attendees) when is_list(attendees) do
    Enum.map(attendees, &format_attendee/1)
  end

  defp format_attendees(_), do: []

  defp format_attendee(address) when is_binary(address) do
    %{
      "emailAddress" => %{"address" => address},
      "type" => "required"
    }
  end

  defp format_attendee(%{"emailAddress" => _} = attendee), do: attendee

  defp format_attendee(%{address: address}) do
    %{"emailAddress" => %{"address" => address}, "type" => "required"}
  end

  defp normalize_event(response_body) do
    case Normalizer.event(response_body) do
      {:ok, event} -> {:ok, %{event: event}}
      {:error, _reason} = error -> error
    end
  end
end
