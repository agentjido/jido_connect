defmodule Jido.Connect.Google.Calendar.Normalizer do
  @moduledoc "Normalizes Google Calendar API payloads into stable package structs."

  alias Jido.Connect.Data
  alias Jido.Connect.Google.Calendar.{AclRule, Attendee, Calendar, Channel, Event, FreeBusy}

  @doc "Normalizes a Google Calendar calendar-list entry payload."
  @spec calendar(map()) :: {:ok, Calendar.t()} | {:error, term()}
  def calendar(payload) when is_map(payload) do
    %{
      calendar_id: Data.get(payload, "id"),
      etag: Data.get(payload, "etag"),
      kind: Data.get(payload, "kind"),
      summary: Data.get(payload, "summary"),
      summary_override: Data.get(payload, "summaryOverride"),
      description: Data.get(payload, "description"),
      location: Data.get(payload, "location"),
      time_zone: Data.get(payload, "timeZone"),
      data_owner: Data.get(payload, "dataOwner"),
      access_role: Data.get(payload, "accessRole"),
      background_color: Data.get(payload, "backgroundColor"),
      foreground_color: Data.get(payload, "foregroundColor"),
      color_id: Data.get(payload, "colorId"),
      selected?: Data.get(payload, "selected", false),
      hidden?: Data.get(payload, "hidden", false),
      primary?: Data.get(payload, "primary", false),
      deleted?: Data.get(payload, "deleted", false),
      auto_accept_invitations?: Data.get(payload, "autoAcceptInvitations"),
      conference_properties: Data.get(payload, "conferenceProperties", %{}),
      default_reminders: Data.get(payload, "defaultReminders", []),
      notification_settings: Data.get(payload, "notificationSettings", %{})
    }
    |> Data.compact()
    |> Calendar.new()
  end

  def calendar(_payload), do: {:error, :invalid_calendar_payload}

  @doc "Normalizes a Google Calendar event attendee payload."
  @spec attendee(map()) :: {:ok, Attendee.t()} | {:error, term()}
  def attendee(payload) when is_map(payload) do
    %{
      email: Data.get(payload, "email"),
      display_name: Data.get(payload, "displayName"),
      response_status: Data.get(payload, "responseStatus"),
      comment: Data.get(payload, "comment"),
      additional_guests: Data.get(payload, "additionalGuests", 0),
      optional?: Data.get(payload, "optional", false),
      organizer?: Data.get(payload, "organizer", false),
      resource?: Data.get(payload, "resource", false),
      self?: Data.get(payload, "self", false)
    }
    |> Data.compact()
    |> Attendee.new()
  end

  def attendee(_payload), do: {:error, :invalid_attendee_payload}

  @doc "Normalizes a Google Calendar event payload."
  @spec event(map(), keyword()) :: {:ok, Event.t()} | {:error, term()}
  def event(payload, opts \\ [])

  def event(payload, opts) when is_map(payload) do
    with {:ok, attendees} <- normalize_attendees(Data.get(payload, "attendees", [])) do
      start = Data.get(payload, "start", %{}) || %{}
      finish = Data.get(payload, "end", %{}) || %{}
      original_start = Data.get(payload, "originalStartTime", %{}) || %{}

      %{
        event_id: Data.get(payload, "id"),
        calendar_id: Keyword.get(opts, :calendar_id),
        i_cal_uid: Data.get(payload, "iCalUID"),
        status: Data.get(payload, "status"),
        summary: Data.get(payload, "summary"),
        description: Data.get(payload, "description"),
        location: Data.get(payload, "location"),
        html_link: Data.get(payload, "htmlLink"),
        creator: Data.get(payload, "creator"),
        organizer: Data.get(payload, "organizer"),
        start: time_value(start),
        end: time_value(finish),
        start_time_zone: Data.get(start, "timeZone"),
        end_time_zone: Data.get(finish, "timeZone"),
        all_day?: all_day?(start),
        recurrence: Data.get(payload, "recurrence", []),
        recurring_event_id: Data.get(payload, "recurringEventId"),
        original_start: time_value(original_start),
        attendees: attendees,
        attendees_omitted?: Data.get(payload, "attendeesOmitted", false),
        hangout_link: Data.get(payload, "hangoutLink"),
        conference_data: Data.get(payload, "conferenceData"),
        reminders: Data.get(payload, "reminders", %{}),
        attachments: Data.get(payload, "attachments", []),
        extended_properties: Data.get(payload, "extendedProperties", %{}),
        transparency: Data.get(payload, "transparency"),
        visibility: Data.get(payload, "visibility"),
        event_type: Data.get(payload, "eventType"),
        created: Data.get(payload, "created"),
        updated: Data.get(payload, "updated"),
        etag: Data.get(payload, "etag"),
        sequence: Data.get(payload, "sequence")
      }
      |> Data.compact()
      |> Event.new()
    end
  end

  def event(_payload, _opts), do: {:error, :invalid_event_payload}

  @doc "Normalizes a Google Calendar notification channel payload."
  @spec channel(map()) :: {:ok, Channel.t()} | {:error, term()}
  def channel(payload) when is_map(payload) do
    %{
      channel_id: Data.get(payload, "id"),
      resource_id: Data.get(payload, "resourceId"),
      resource_uri: Data.get(payload, "resourceUri"),
      token: Data.get(payload, "token"),
      expiration: normalize_string(Data.get(payload, "expiration")),
      type: Data.get(payload, "type"),
      address: Data.get(payload, "address"),
      kind: Data.get(payload, "kind"),
      params: Data.get(payload, "params", %{})
    }
    |> Data.compact()
    |> Channel.new()
  end

  def channel(_payload), do: {:error, :invalid_channel_payload}

  @doc "Normalizes a Google Calendar ACL rule payload."
  @spec acl_rule(map(), keyword()) :: {:ok, AclRule.t()} | {:error, term()}
  def acl_rule(payload, opts \\ [])

  def acl_rule(payload, opts) when is_map(payload) do
    scope = Data.get(payload, "scope", %{}) || %{}

    %{
      acl_rule_id: Data.get(payload, "id"),
      calendar_id: Keyword.get(opts, :calendar_id),
      role: Data.get(payload, "role"),
      scope_type: Data.get(scope, "type"),
      scope_value: Data.get(scope, "value"),
      etag: Data.get(payload, "etag"),
      kind: Data.get(payload, "kind")
    }
    |> Data.compact()
    |> AclRule.new()
  end

  def acl_rule(_payload, _opts), do: {:error, :invalid_acl_rule_payload}

  @doc "Normalizes a Google Calendar free/busy response payload."
  @spec free_busy(map()) :: {:ok, FreeBusy.t()} | {:error, term()}
  def free_busy(payload) when is_map(payload) do
    calendars = Data.get(payload, "calendars", %{}) || %{}
    groups = Data.get(payload, "groups", %{}) || %{}

    %{
      time_min: Data.get(payload, "timeMin"),
      time_max: Data.get(payload, "timeMax"),
      calendars: calendars,
      groups: groups,
      busy: busy_windows(calendars),
      errors: free_busy_errors(calendars, groups)
    }
    |> Data.compact()
    |> FreeBusy.new()
  end

  def free_busy(_payload), do: {:error, :invalid_free_busy_payload}

  defp normalize_attendees(attendees) when is_list(attendees) do
    attendees
    |> Enum.reduce_while({:ok, []}, fn payload, {:ok, acc} ->
      case attendee(payload) do
        {:ok, attendee} -> {:cont, {:ok, [attendee | acc]}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, attendees} -> {:ok, Enum.reverse(attendees)}
      {:error, error} -> {:error, error}
    end
  end

  defp normalize_attendees(_attendees), do: {:error, :invalid_attendees_payload}

  defp time_value(payload) when is_map(payload) do
    Data.get(payload, "dateTime") || Data.get(payload, "date")
  end

  defp time_value(_payload), do: nil

  defp normalize_string(value) when is_integer(value), do: Integer.to_string(value)
  defp normalize_string(value) when is_binary(value), do: value
  defp normalize_string(value), do: value

  defp all_day?(payload) when is_map(payload), do: is_binary(Data.get(payload, "date"))
  defp all_day?(_payload), do: false

  defp busy_windows(calendars) when is_map(calendars) do
    Enum.flat_map(calendars, fn {calendar_id, payload} ->
      payload
      |> Data.get("busy", [])
      |> Enum.map(fn window ->
        %{
          calendar_id: calendar_id,
          start: Data.get(window, "start"),
          end: Data.get(window, "end")
        }
        |> Data.compact()
      end)
    end)
  end

  defp busy_windows(_calendars), do: []

  defp free_busy_errors(calendars, groups) do
    flatten_free_busy_errors(:calendar, calendars) ++ flatten_free_busy_errors(:group, groups)
  end

  defp flatten_free_busy_errors(type, entries) when is_map(entries) do
    Enum.flat_map(entries, fn {id, payload} ->
      payload
      |> Data.get("errors", [])
      |> Enum.map(fn error ->
        %{
          target_type: type,
          target_id: id,
          domain: Data.get(error, "domain"),
          reason: Data.get(error, "reason")
        }
        |> Data.compact()
      end)
    end)
  end

  defp flatten_free_busy_errors(_type, _entries), do: []
end
