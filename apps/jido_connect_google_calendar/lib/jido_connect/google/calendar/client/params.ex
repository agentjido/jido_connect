defmodule Jido.Connect.Google.Calendar.Client.Params do
  @moduledoc "Google Calendar request parameter helpers."

  alias Jido.Connect.Data

  @default_calendar_fields [
    "id",
    "summary",
    "summaryOverride",
    "description",
    "location",
    "timeZone",
    "accessRole",
    "backgroundColor",
    "foregroundColor",
    "colorId",
    "selected",
    "hidden",
    "primary",
    "deleted",
    "defaultReminders",
    "notificationSettings"
  ]

  @default_event_fields [
    "id",
    "iCalUID",
    "status",
    "summary",
    "description",
    "location",
    "htmlLink",
    "creator",
    "organizer",
    "start",
    "end",
    "recurrence",
    "recurringEventId",
    "originalStartTime",
    "attendees",
    "attendeesOmitted",
    "hangoutLink",
    "conferenceData",
    "reminders",
    "attachments",
    "extendedProperties",
    "transparency",
    "visibility",
    "eventType",
    "created",
    "updated",
    "etag",
    "sequence"
  ]

  @doc "Default calendar-list entry fields used by read actions."
  def default_calendar_fields, do: Enum.join(@default_calendar_fields, ",")

  @doc "Default event fields used by read actions."
  def default_event_fields, do: Enum.join(@default_event_fields, ",")

  @doc "Builds query params for `calendarList.list`."
  def list_calendars_params(params) do
    %{
      maxResults: Data.get(params, :page_size, 100),
      pageToken: Data.get(params, :page_token),
      fields: Data.get(params, :fields, calendar_list_fields()),
      minAccessRole: Data.get(params, :min_access_role),
      showDeleted: Data.get(params, :show_deleted),
      showHidden: Data.get(params, :show_hidden),
      syncToken: Data.get(params, :sync_token)
    }
    |> Data.compact()
  end

  @doc "Builds query params for calendar get-style requests."
  def get_calendar_params(params) do
    %{
      fields: Data.get(params, :fields)
    }
    |> Data.compact()
  end

  @doc "Builds query params for `events.list`."
  def list_events_params(params) do
    %{
      maxResults: Data.get(params, :page_size, 250),
      pageToken: Data.get(params, :page_token),
      fields: Data.get(params, :fields, event_list_fields()),
      timeMin: Data.get(params, :time_min),
      timeMax: Data.get(params, :time_max),
      timeZone: Data.get(params, :time_zone),
      updatedMin: Data.get(params, :updated_min),
      q: Data.get(params, :q),
      singleEvents: Data.get(params, :single_events),
      showDeleted: Data.get(params, :show_deleted),
      showHiddenInvitations: Data.get(params, :show_hidden_invitations),
      orderBy: Data.get(params, :order_by),
      syncToken: Data.get(params, :sync_token),
      maxAttendees: Data.get(params, :max_attendees),
      eventTypes: Data.get(params, :event_types)
    }
    |> Data.compact()
  end

  @doc "Builds query params for `events.watch`."
  def watch_events_params(params) do
    %{
      eventTypes: Data.get(params, :event_types)
    }
    |> Data.compact()
  end

  @doc "Builds query params for `events.get`."
  def get_event_params(params) do
    %{
      fields: Data.get(params, :fields, default_event_fields()),
      timeZone: Data.get(params, :time_zone),
      maxAttendees: Data.get(params, :max_attendees)
    }
    |> Data.compact()
  end

  @doc "Builds query params for `events.instances`."
  def event_instances_params(params) do
    %{
      maxResults: Data.get(params, :page_size, 250),
      pageToken: Data.get(params, :page_token),
      fields: Data.get(params, :fields, event_list_fields()),
      timeMin: Data.get(params, :time_min),
      timeMax: Data.get(params, :time_max),
      timeZone: Data.get(params, :time_zone),
      originalStart: Data.get(params, :original_start),
      showDeleted: Data.get(params, :show_deleted),
      maxAttendees: Data.get(params, :max_attendees)
    }
    |> Data.compact()
  end

  @doc "Builds query params for `events.insert` and `events.patch`."
  def event_mutation_params(params) do
    %{
      fields: Data.get(params, :fields, default_event_fields()),
      conferenceDataVersion: Data.get(params, :conference_data_version),
      maxAttendees: Data.get(params, :max_attendees),
      sendUpdates: Data.get(params, :send_updates),
      supportsAttachments: Data.get(params, :supports_attachments)
    }
    |> Data.compact()
  end

  @doc "Builds query params for `events.delete`."
  def delete_event_params(params) do
    %{
      sendUpdates: Data.get(params, :send_updates)
    }
    |> Data.compact()
  end

  @doc "Builds query params for `events.move`."
  def event_move_params(params) do
    %{
      destination: destination_calendar_id(params),
      sendNotifications: Data.get(params, :send_notifications),
      sendUpdates: Data.get(params, :send_updates)
    }
    |> Data.compact()
  end

  @doc "Returns the normalized destination calendar id for event moves."
  def destination_calendar_id(params) do
    Data.get(params, :destination_calendar_id) || Data.get(params, :destination)
  end

  @doc "Builds a Google Calendar freeBusy request body."
  def free_busy_body(params) do
    %{
      timeMin: Data.get(params, :time_min),
      timeMax: Data.get(params, :time_max),
      timeZone: Data.get(params, :time_zone),
      groupExpansionMax: Data.get(params, :group_expansion_max),
      calendarExpansionMax: Data.get(params, :calendar_expansion_max),
      items: free_busy_items(Data.get(params, :calendar_ids, []))
    }
    |> Data.compact()
  end

  @doc "Builds a Calendars resource body."
  def calendar_body(params) do
    %{
      summary: Data.get(params, :summary),
      description: Data.get(params, :description),
      location: Data.get(params, :location),
      timeZone: Data.get(params, :time_zone),
      conferenceProperties: Data.get(params, :conference_properties),
      autoAcceptInvitations: Data.get(params, :auto_accept_invitations)
    }
    |> Data.compact()
  end

  @doc "Builds query params for CalendarList mutations."
  def calendar_list_mutation_params(params) do
    %{
      colorRgbFormat: Data.get(params, :color_rgb_format)
    }
    |> Data.compact()
  end

  @doc "Builds a CalendarList entry body."
  def calendar_list_entry_body(params) do
    %{
      id: Data.get(params, :calendar_id),
      summaryOverride: Data.get(params, :summary_override),
      colorId: Data.get(params, :color_id),
      backgroundColor: Data.get(params, :background_color),
      foregroundColor: Data.get(params, :foreground_color),
      selected: Data.get(params, :selected),
      hidden: Data.get(params, :hidden),
      defaultReminders: Data.get(params, :default_reminders),
      notificationSettings: Data.get(params, :notification_settings)
    }
    |> Data.compact()
  end

  @doc "Builds query params for `acl.list`."
  def list_acl_params(params) do
    %{
      maxResults: Data.get(params, :page_size, 100),
      pageToken: Data.get(params, :page_token),
      fields: Data.get(params, :fields, acl_list_fields()),
      showDeleted: Data.get(params, :show_deleted),
      syncToken: Data.get(params, :sync_token)
    }
    |> Data.compact()
  end

  @doc "Builds query params for `acl.get`."
  def get_acl_params(params) do
    %{
      fields: Data.get(params, :fields, default_acl_fields())
    }
    |> Data.compact()
  end

  @doc "Builds query params for ACL mutations."
  def acl_mutation_params(params) do
    %{
      sendNotifications: Data.get(params, :send_notifications)
    }
    |> Data.compact()
  end

  @doc "Builds an ACL rule body."
  def acl_rule_body(params) do
    %{
      role: Data.get(params, :role),
      scope: acl_scope_body(params)
    }
    |> Data.compact()
  end

  @doc "Builds a channel JSON body for Calendar watch requests."
  def watch_channel_body(params) do
    ttl =
      Data.get(params, :ttl_seconds) ||
        ttl_from_expiration_ms(Data.get(params, :expiration_ms))

    %{
      id: Data.get(params, :channel_id),
      type: Data.get(params, :channel_type, "web_hook"),
      address: Data.get(params, :address),
      token: Data.get(params, :token),
      params: channel_params(Data.get(params, :delivery_params), ttl)
    }
    |> Data.compact()
  end

  @doc "Builds a channel JSON body for `channels.stop`."
  def stop_channel_body(params) do
    %{
      id: Data.get(params, :channel_id),
      resourceId: Data.get(params, :resource_id)
    }
    |> Data.compact()
  end

  @doc "Builds a Google Calendar event body for create requests."
  def event_create_body(params), do: event_body(params, include_id?: true)

  @doc "Builds a Google Calendar event body for patch requests."
  def event_update_body(params), do: event_body(params, include_id?: false)

  defp calendar_list_fields,
    do: "nextPageToken,nextSyncToken,items(#{default_calendar_fields()})"

  defp event_list_fields,
    do: "nextPageToken,nextSyncToken,items(#{default_event_fields()})"

  defp default_acl_fields, do: "id,etag,kind,role,scope"

  defp acl_list_fields, do: "nextPageToken,nextSyncToken,items(#{default_acl_fields()})"

  defp acl_scope_body(params) do
    %{
      type: Data.get(params, :scope_type),
      value: Data.get(params, :scope_value)
    }
    |> Data.compact()
  end

  defp event_body(params, opts) do
    base =
      %{
        summary: Data.get(params, :summary),
        description: Data.get(params, :description),
        location: Data.get(params, :location),
        colorId: Data.get(params, :color_id),
        start: event_time_body(params, :start),
        end: event_time_body(params, :end),
        attendees: event_attendees_body(params),
        recurrence: Data.get(params, :recurrence),
        reminders: Data.get(params, :reminders),
        conferenceData: Data.get(params, :conference_data),
        attachments: Data.get(params, :attachments),
        extendedProperties: Data.get(params, :extended_properties),
        transparency: Data.get(params, :transparency),
        visibility: Data.get(params, :visibility),
        guestsCanInviteOthers: Data.get(params, :guests_can_invite_others),
        guestsCanModify: Data.get(params, :guests_can_modify),
        guestsCanSeeOtherGuests: Data.get(params, :guests_can_see_other_guests)
      }
      |> Data.compact()

    if Keyword.get(opts, :include_id?) do
      base
      |> Map.put(:id, Data.get(params, :event_id))
      |> Data.compact()
    else
      base
    end
  end

  defp event_time_body(params, field) do
    case Data.get(params, field) do
      value when is_binary(value) ->
        if Data.get(params, :all_day, false) do
          %{date: value}
        else
          %{
            dateTime: value,
            timeZone: time_zone(params, field)
          }
          |> Data.compact()
        end

      _missing ->
        nil
    end
  end

  defp event_attendees_body(params) do
    case Data.get(params, :attendees) do
      attendees when is_list(attendees) ->
        Enum.map(attendees, &event_attendee_body/1)

      _missing ->
        nil
    end
  end

  defp event_attendee_body(attendee) do
    %{
      email: Data.get(attendee, :email),
      displayName: Data.get(attendee, :display_name),
      optional: Data.get(attendee, :optional),
      responseStatus: Data.get(attendee, :response_status),
      comment: Data.get(attendee, :comment),
      additionalGuests: Data.get(attendee, :additional_guests)
    }
    |> Data.compact()
  end

  defp time_zone(params, :start) do
    Data.get(params, :start_time_zone) || Data.get(params, :time_zone)
  end

  defp time_zone(params, :end) do
    Data.get(params, :end_time_zone) || Data.get(params, :time_zone)
  end

  defp free_busy_items(calendar_ids) when is_list(calendar_ids) do
    Enum.map(calendar_ids, &%{id: &1})
  end

  defp free_busy_items(_calendar_ids), do: []

  defp channel_params(params, nil), do: params

  defp channel_params(params, ttl) when is_map(params) do
    Map.put(params, :ttl, to_string(ttl))
  end

  defp channel_params(_params, ttl), do: %{ttl: to_string(ttl)}

  defp ttl_from_expiration_ms(expiration_ms) when is_integer(expiration_ms) do
    now_ms = System.system_time(:millisecond)
    max(div(expiration_ms - now_ms, 1000), 0)
  end

  defp ttl_from_expiration_ms(_expiration_ms), do: nil
end
