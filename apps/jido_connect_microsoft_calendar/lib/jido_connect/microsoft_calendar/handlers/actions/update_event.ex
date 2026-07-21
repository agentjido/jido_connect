defmodule Jido.Connect.MicrosoftCalendar.Handlers.Actions.UpdateEvent do
  @moduledoc false

  alias Jido.Connect.Microsoft.Transport
  alias Jido.Connect.MicrosoftCalendar.Normalizer

  @doc """
  Updates an existing Microsoft Calendar event via Microsoft Graph.

  PATCH /me/events/{event_id} or PATCH /me/calendars/{calendar_id}/events/{event_id}
  with a JSON body containing only the fields to update.
  """
  def run(input, %{credentials: %{access_token: access_token}})
      when is_binary(access_token) do
    case Map.get(input, :event_id) do
      nil ->
        {:error, :event_id_required}

      event_id ->
        body = build_update_body(input)
        request = Transport.request(access_token)
        url = event_url(Map.get(input, :calendar_id), event_id)

        case Transport.request(request, :patch, url: url, json: body) do
          {:ok, %{status: 200, body: response_body}} when is_map(response_body) ->
            case Normalizer.event(response_body) do
              {:ok, event} -> {:ok, %{event: event}}
              {:error, _reason} = error -> error
            end

          {:ok, response} ->
            Transport.handle_error_response({:ok, response},
              message: "Failed to update Microsoft calendar event"
            )

          {:error, _reason} = error ->
            Transport.handle_error_response(error,
              message: "Failed to update Microsoft calendar event"
            )
        end
    end
  end

  def run(_input, _context), do: {:error, :missing_access_token}

  defp event_url(nil, event_id), do: "/me/events/#{event_id}"
  defp event_url(calendar_id, event_id), do: "/me/calendars/#{calendar_id}/events/#{event_id}"

  defp build_update_body(input) do
    body = %{}

    body =
      case Map.get(input, :subject) do
        nil -> body
        subject -> Map.put(body, "subject", subject)
      end

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

    time_zone = Map.get(input, :time_zone)

    body =
      case {Map.get(input, :start_date_time), time_zone} do
        {nil, _} -> body
        {start_dt, nil} -> Map.put(body, "start", %{"dateTime" => start_dt, "timeZone" => "UTC"})
        {start_dt, tz} -> Map.put(body, "start", %{"dateTime" => start_dt, "timeZone" => tz})
      end

    body =
      case {Map.get(input, :end_date_time), time_zone} do
        {nil, _} -> body
        {end_dt, nil} -> Map.put(body, "end", %{"dateTime" => end_dt, "timeZone" => "UTC"})
        {end_dt, tz} -> Map.put(body, "end", %{"dateTime" => end_dt, "timeZone" => tz})
      end

    body =
      case Map.get(input, :location) do
        nil -> body
        loc -> Map.put(body, "location", %{"displayName" => loc})
      end

    body =
      case Map.get(input, :attendees) do
        nil -> body
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

    body
  end

  defp format_attendees(attendees) when is_list(attendees) do
    Enum.map(attendees, &format_attendee/1)
  end

  defp format_attendees(_), do: []

  defp format_attendee(address) when is_binary(address) do
    %{"emailAddress" => %{"address" => address}, "type" => "required"}
  end

  defp format_attendee(%{"emailAddress" => _} = attendee), do: attendee

  defp format_attendee(%{address: address}) do
    %{"emailAddress" => %{"address" => address}, "type" => "required"}
  end
end
