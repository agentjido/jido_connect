defmodule Jido.Connect.MicrosoftCalendar.Handlers.Actions.FindMeetingTimes do
  @moduledoc false

  alias Jido.Connect.Microsoft.Transport

  @doc """
  Suggests meeting times based on attendee availability via Microsoft Graph
  `findMeetingTimes`.

  Input:
  - `attendees` (optional) - list of email addresses
  - `start_date_time` / `end_date_time` - time window
  - `time_zone` (default: "UTC")
  - `meeting_duration` (default: "PT1H") - ISO 8601 duration
  - `is_org_app_required` (optional)
  - `return_suggestion_reasons` (default: true)
  - `minimum_attendee_percentage` (optional)
  """
  def run(input, %{credentials: %{access_token: access_token}})
      when is_binary(access_token) do
    request = Transport.request(access_token)
    body = build_request_body(input)

    case Transport.request(request, :post,
           url: "/me/findMeetingTimes",
           json: body
         ) do
      {:ok, %{status: 200, body: response_body}} when is_map(response_body) ->
        suggestions = normalize_suggestions(response_body)
        empty_reason = response_body["emptySuggestionsReason"]

        {:ok,
         %{
           suggestions: suggestions,
           empty_suggestions_reason: empty_reason
         }}

      {:ok, response} ->
        Transport.handle_error_response({:ok, response},
          message: "Failed to find Microsoft calendar meeting times"
        )

      {:error, _reason} = error ->
        Transport.handle_error_response(error,
          message: "Failed to find Microsoft calendar meeting times"
        )
    end
  end

  def run(_input, _context), do: {:error, :missing_access_token}

  defp build_request_body(input) do
    time_zone = Map.get(input, :time_zone, "UTC")

    body = %{}

    body =
      case Map.get(input, :attendees) do
        nil ->
          body

        attendees when is_list(attendees) ->
          Map.put(body, :attendees, Enum.map(attendees, &build_attendee/1))
      end

    body =
      case {Map.get(input, :start_date_time), Map.get(input, :end_date_time)} do
        {nil, _} ->
          body

        {_, nil} ->
          body

        {start_dt, end_dt} ->
          time_slot = %{
            start: %{dateTime: start_dt, timeZone: time_zone},
            end: %{dateTime: end_dt, timeZone: time_zone}
          }

          time_constraint = %{timeslots: [time_slot]}
          Map.put(body, :timeConstraint, time_constraint)
      end

    body =
      case Map.get(input, :meeting_duration) do
        nil -> body
        duration -> Map.put(body, :meetingDuration, duration)
      end

    body =
      case Map.get(input, :is_org_app_required) do
        nil -> body
        val -> Map.put(body, :isOrganizerOptional, val)
      end

    body =
      case Map.get(input, :return_suggestion_reasons) do
        nil -> body
        val -> Map.put(body, :returnSuggestionReasons, val)
      end

    body =
      case Map.get(input, :minimum_attendee_percentage) do
        nil -> body
        val -> Map.put(body, :minimumAttendeePercentage, val)
      end

    body
  end

  defp build_attendee(email) when is_binary(email) do
    %{
      type: "required",
      emailAddress: %{address: email}
    }
  end

  defp build_attendee(%{address: address} = map) do
    %{type: Map.get(map, :type, "required"), emailAddress: %{address: address}}
  end

  defp normalize_suggestions(%{"meetingTimeSuggestions" => suggestions})
       when is_list(suggestions) do
    Enum.map(suggestions, &normalize_suggestion/1)
  end

  defp normalize_suggestions(_body), do: []

  defp normalize_suggestion(suggestion) when is_map(suggestion) do
    %{
      confidence: suggestion["confidence"],
      meeting_time_slot: suggestion["meetingTimeSlot"],
      locations: suggestion["locations"],
      organizer_availability: suggestion["organizerAvailability"],
      attendee_availability: suggestion["attendeeAvailability"],
      suggestion_reason: suggestion["suggestionReason"],
      order: suggestion["order"]
    }
    |> compact_map()
  end

  defp normalize_suggestion(_), do: %{}

  defp compact_map(map) do
    map
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end
end
