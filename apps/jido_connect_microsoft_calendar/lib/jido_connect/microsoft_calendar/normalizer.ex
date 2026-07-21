defmodule Jido.Connect.MicrosoftCalendar.Normalizer do
  @moduledoc """
  Normalizes Microsoft Graph Calendar API payloads into stable, body-safe
  package structs.

  This module is read/shape only. It accepts decoded JSON maps (typically from
  fixtures or Transport responses) and produces validated Zoi structs for
  calendars, calendar groups, events, attendees, locations, recurrence,
  free-busy slots, and availability results.

  No HTTP actions are performed here — all input is fixture-driven.
  """

  alias Jido.Connect.Data

  alias Jido.Connect.MicrosoftCalendar.{
    Attendee,
    AvailabilityResult,
    Calendar,
    CalendarGroup,
    Event,
    FreeBusySlot,
    Location,
    Recurrence
  }

  # ── Calendar ──────────────────────────────────────────────────────────

  @doc "Normalizes a Microsoft Graph `calendar` payload."
  @spec calendar(map()) :: {:ok, Calendar.t()} | {:error, term()}
  def calendar(payload) when is_map(payload) do
    %{
      calendar_id: Data.get(payload, "id"),
      name: Data.get(payload, "name"),
      color: Data.get(payload, "color"),
      hex_color: Data.get(payload, "hexColor"),
      is_default_calendar: Data.get(payload, "isDefaultCalendar"),
      is_shared: Data.get(payload, "isShared"),
      is_tallying_replies: Data.get(payload, "isTallyingReplies"),
      owner: normalize_email_address(Data.get(payload, "owner")),
      calendar_group_id: Data.get(payload, "calendarGroupId"),
      can_edit: Data.get(payload, "canEdit"),
      can_share: Data.get(payload, "canShare"),
      can_view_private_items: Data.get(payload, "canViewPrivateItems")
    }
    |> Data.compact()
    |> Calendar.new()
  end

  def calendar(_payload), do: {:error, :invalid_calendar_payload}

  # ── Calendar Group ────────────────────────────────────────────────────

  @doc "Normalizes a Microsoft Graph `calendarGroup` payload."
  @spec calendar_group(map()) :: {:ok, CalendarGroup.t()} | {:error, term()}
  def calendar_group(payload) when is_map(payload) do
    %{
      group_id: Data.get(payload, "id"),
      name: Data.get(payload, "name"),
      class_id: Data.get(payload, "classId"),
      change_key: Data.get(payload, "changeKey"),
      calendar_count: normalize_integer(Data.get(payload, "calendars"))
    }
    |> Data.compact()
    |> CalendarGroup.new()
  end

  def calendar_group(_payload), do: {:error, :invalid_calendar_group_payload}

  # ── Event ─────────────────────────────────────────────────────────────

  @doc "Normalizes a Microsoft Graph `event` payload without body content leakage."
  @spec event(map()) :: {:ok, Event.t()} | {:error, term()}
  def event(payload) when is_map(payload) do
    %{
      event_id: Data.get(payload, "id"),
      i_cal_uid: Data.get(payload, "iCalUId"),
      subject: Data.get(payload, "subject"),
      body_preview: Data.get(payload, "bodyPreview"),
      body_summary: summarize_body(Data.get(payload, "body")),
      start: normalize_date_time(Data.get(payload, "start")),
      end: normalize_date_time(Data.get(payload, "end")),
      organizer: normalize_organizer(Data.get(payload, "organizer")),
      attendees: normalize_attendees(Data.get(payload, "attendees")),
      location: normalize_location_map(Data.get(payload, "location")),
      locations: normalize_locations(Data.get(payload, "locations")),
      recurrence: normalize_recurrence_map(Data.get(payload, "recurrence")),
      is_all_day: Data.get(payload, "isAllDay"),
      is_cancelled: Data.get(payload, "isCancelled"),
      is_organizer: Data.get(payload, "isOrganizer"),
      sensitivity: Data.get(payload, "sensitivity"),
      show_as: Data.get(payload, "showAs"),
      series_master_id: Data.get(payload, "seriesMasterId"),
      transaction_id: Data.get(payload, "transactionId"),
      online_meeting_url: Data.get(payload, "onlineMeetingUrl"),
      online_meeting: normalize_online_meeting(Data.get(payload, "onlineMeeting")),
      response_status: Data.get(payload, "responseStatus"),
      has_attachments: Data.get(payload, "hasAttachments"),
      calendar_id: Data.get(payload, "calendar")
    }
    |> Data.compact()
    |> Event.new()
  end

  def event(_payload), do: {:error, :invalid_event_payload}

  # ── Attendee ──────────────────────────────────────────────────────────

  @doc "Normalizes a single Microsoft Graph `attendee` object."
  @spec attendee(map()) :: {:ok, Attendee.t()} | {:error, term()}
  def attendee(payload) when is_map(payload) do
    email_address = Data.get(payload, "emailAddress", %{})

    %{
      name: Data.get(email_address, "name"),
      address: Data.get(email_address, "address"),
      type: Data.get(payload, "type"),
      status: normalize_attendee_status(Data.get(payload, "status"))
    }
    |> Data.compact()
    |> Attendee.new()
  end

  def attendee(_payload), do: {:error, :invalid_attendee_payload}

  # ── Location ──────────────────────────────────────────────────────────

  @doc "Normalizes a Microsoft Graph `location` object."
  @spec location(map()) :: {:ok, Location.t()} | {:error, term()}
  def location(payload) when is_map(payload) do
    %{
      display_name: Data.get(payload, "displayName"),
      location_uri: Data.get(payload, "locationUri"),
      location_type: Data.get(payload, "locationType"),
      address: Data.get(payload, "address"),
      coordinates: Data.get(payload, "coordinates")
    }
    |> Data.compact()
    |> Location.new()
  end

  def location(_payload), do: {:error, :invalid_location_payload}

  # ── Recurrence ────────────────────────────────────────────────────────

  @doc "Normalizes a Microsoft Graph `patternedRecurrence` object."
  @spec recurrence(map()) :: {:ok, Recurrence.t()} | {:error, term()}
  def recurrence(payload) when is_map(payload) do
    %{
      pattern: normalize_recurrence_pattern(Data.get(payload, "pattern")),
      range: normalize_recurrence_range(Data.get(payload, "range"))
    }
    |> Data.compact()
    |> Recurrence.new()
  end

  def recurrence(_payload), do: {:error, :invalid_recurrence_payload}

  # ── FreeBusy Slot ─────────────────────────────────────────────────────

  @doc "Normalizes a Microsoft Graph `scheduleItem` (free/busy slot)."
  @spec freebusy_slot(map()) :: {:ok, FreeBusySlot.t()} | {:error, term()}
  def freebusy_slot(payload) when is_map(payload) do
    %{
      start: normalize_date_time(Data.get(payload, "start")),
      end: normalize_date_time(Data.get(payload, "end")),
      status: Data.get(payload, "status")
    }
    |> Data.compact()
    |> FreeBusySlot.new()
  end

  def freebusy_slot(_payload), do: {:error, :invalid_freebusy_slot_payload}

  # ── Availability Result ───────────────────────────────────────────────

  @doc "Normalizes a Microsoft Graph `scheduleInformation` (availability result)."
  @spec availability_result(map()) :: {:ok, AvailabilityResult.t()} | {:error, term()}
  def availability_result(payload) when is_map(payload) do
    %{
      schedule_id: Data.get(payload, "scheduleId"),
      availability_view: Data.get(payload, "availabilityView"),
      slots: normalize_freebusy_slots(Data.get(payload, "scheduleItems")),
      error: Data.get(payload, "error")
    }
    |> Data.compact()
    |> AvailabilityResult.new()
  end

  def availability_result(_payload), do: {:error, :invalid_availability_result_payload}

  # ── Paging envelope ───────────────────────────────────────────────────

  @doc """
  Extracts the normalized page of items and next-link from a Microsoft Graph
  OData list envelope.

  Returns `{:ok, %{items: [...], next_link: nil | binary()}}`.
  """
  @spec page(map(), (map() -> {:ok, struct()} | {:error, term()})) ::
          {:ok, %{items: [struct()], next_link: String.t() | nil}}
          | {:error, term()}
  def page(envelope, normalizer) when is_map(envelope) and is_function(normalizer, 1) do
    values = Data.get(envelope, "value", [])
    next = Data.get(envelope, "@odata.nextLink")

    case normalize_list(values, normalizer) do
      {:ok, items} -> {:ok, %{items: items, next_link: next}}
      {:error, reason} -> {:error, reason}
    end
  end

  def page(_envelope, _normalizer), do: {:error, :invalid_page_envelope}

  # ── Batch helpers ─────────────────────────────────────────────────────

  @doc "Normalizes a list of payloads using the given normalizer function."
  @spec normalize_list([map()], (map() -> {:ok, struct()} | {:error, term()})) ::
          {:ok, [struct()]} | {:error, term()}
  def normalize_list(payloads, normalizer)
      when is_list(payloads) and is_function(normalizer, 1) do
    Enum.reduce_while(payloads, {:ok, []}, fn payload, {:ok, acc} ->
      case normalizer.(payload) do
        {:ok, item} -> {:cont, {:ok, [item | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, items} -> {:ok, Enum.reverse(items)}
      {:error, reason} -> {:error, reason}
    end
  end

  def normalize_list(_payloads, _normalizer), do: {:error, :invalid_list_payloads}

  # ── Private helpers ───────────────────────────────────────────────────

  defp summarize_body(%{} = body) do
    %{
      content_type: Data.get(body, "contentType"),
      body_size: body |> Data.get("content", "") |> byte_size()
    }
    |> Data.compact()
  end

  defp summarize_body(_body), do: %{}

  defp normalize_date_time(%{} = dt) do
    %{
      date_time: Data.get(dt, "dateTime"),
      time_zone: Data.get(dt, "timeZone")
    }
    |> Data.compact()
  end

  defp normalize_date_time(_dt), do: nil

  defp normalize_email_address(%{} = addr) do
    %{
      name: Data.get(addr, "name"),
      address: Data.get(addr, "address")
    }
    |> Data.compact()
  end

  defp normalize_email_address(_addr), do: nil

  defp normalize_organizer(%{} = org) do
    email_address = Data.get(org, "emailAddress", %{})

    %{
      name: Data.get(email_address, "name"),
      address: Data.get(email_address, "address")
    }
    |> Data.compact()
  end

  defp normalize_organizer(_org), do: nil

  defp normalize_attendees(attendees) when is_list(attendees) do
    attendees
    |> Enum.map(&normalize_attendee_map/1)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_attendees(_attendees), do: []

  defp normalize_attendee_map(%{} = attendee) do
    email_address = Data.get(attendee, "emailAddress", %{})

    %{
      name: Data.get(email_address, "name"),
      address: Data.get(email_address, "address"),
      type: Data.get(attendee, "type"),
      status: normalize_attendee_status(Data.get(attendee, "status"))
    }
    |> Data.compact()
  end

  defp normalize_attendee_map(_attendee), do: nil

  defp normalize_attendee_status(%{} = status) do
    %{
      response: Data.get(status, "response"),
      time: Data.get(status, "time")
    }
    |> Data.compact()
  end

  defp normalize_attendee_status(_status), do: nil

  defp normalize_location_map(%{} = loc) do
    %{
      display_name: Data.get(loc, "displayName"),
      location_uri: Data.get(loc, "locationUri"),
      location_type: Data.get(loc, "locationType"),
      address: Data.get(loc, "address"),
      coordinates: Data.get(loc, "coordinates")
    }
    |> Data.compact()
  end

  defp normalize_location_map(_loc), do: nil

  defp normalize_locations(locations) when is_list(locations) do
    locations
    |> Enum.map(&normalize_location_map/1)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_locations(_locations), do: []

  defp normalize_recurrence_map(%{} = rec) do
    %{
      pattern: normalize_recurrence_pattern(Data.get(rec, "pattern")),
      range: normalize_recurrence_range(Data.get(rec, "range"))
    }
    |> Data.compact()
  end

  defp normalize_recurrence_map(_rec), do: nil

  defp normalize_recurrence_pattern(%{} = pattern) do
    %{
      type: Data.get(pattern, "type"),
      interval: normalize_integer(Data.get(pattern, "interval")),
      month: normalize_integer(Data.get(pattern, "month")),
      day_of_month: normalize_integer(Data.get(pattern, "dayOfMonth")),
      days_of_week: Data.get(pattern, "daysOfWeek"),
      first_day_of_week: Data.get(pattern, "firstDayOfWeek"),
      index: Data.get(pattern, "index")
    }
    |> Data.compact()
  end

  defp normalize_recurrence_pattern(_pattern), do: nil

  defp normalize_recurrence_range(%{} = range) do
    %{
      type: Data.get(range, "type"),
      start_date: Data.get(range, "startDate"),
      end_date: Data.get(range, "endDate"),
      recurrence_time_zone: Data.get(range, "recurrenceTimeZone"),
      number_of_occurrences: normalize_integer(Data.get(range, "numberOfOccurrences"))
    }
    |> Data.compact()
  end

  defp normalize_recurrence_range(_range), do: nil

  defp normalize_online_meeting(%{} = meeting) do
    %{
      join_url: Data.get(meeting, "joinUrl"),
      conference_id: Data.get(meeting, "conferenceId"),
      toll_free_number: Data.get(meeting, "tollFreeNumber"),
      toll_number: Data.get(meeting, "tollNumber")
    }
    |> Data.compact()
  end

  defp normalize_online_meeting(_meeting), do: nil

  defp normalize_freebusy_slots(slots) when is_list(slots) do
    slots
    |> Enum.map(&normalize_freebusy_slot_map/1)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_freebusy_slots(_slots), do: []

  defp normalize_freebusy_slot_map(%{} = slot) do
    %{
      start: normalize_date_time(Data.get(slot, "start")),
      end: normalize_date_time(Data.get(slot, "end")),
      status: Data.get(slot, "status")
    }
    |> Data.compact()
  end

  defp normalize_freebusy_slot_map(_slot), do: nil

  defp normalize_integer(value) when is_integer(value), do: value

  defp normalize_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} -> integer
      _other -> nil
    end
  end

  defp normalize_integer(_value), do: nil
end
