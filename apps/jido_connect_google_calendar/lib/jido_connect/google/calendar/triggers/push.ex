defmodule Jido.Connect.Google.Calendar.Triggers.Push do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @calendar_list_scope "https://www.googleapis.com/auth/calendar.calendarlist.readonly"
  @events_readonly_scope "https://www.googleapis.com/auth/calendar.events.readonly"
  @acl_readonly_scope "https://www.googleapis.com/auth/calendar.acls.readonly"
  @settings_readonly_scope "https://www.googleapis.com/auth/calendar.settings.readonly"
  @scope_resolver Jido.Connect.Google.Calendar.ScopeResolver

  triggers do
    webhook :event_changed_push do
      id("google.calendar.event.changed.push")
      resource(:event)
      verb(:watch)
      data_classification(:personal_data)
      label("Event changed push")
      description("Receive Google Calendar push notifications for event watch channels.")

      verification(%{
        kind: :google_calendar_channel,
        token: :host_verified,
        headers: :x_goog_channel
      })

      dedupe(%{key: [:channel_id, :resource_id, :message_number]})
      handler(Jido.Connect.Google.Calendar.Handlers.Triggers.CalendarChangedWebhook)

      access do
        auth(:user)
        scopes([@events_readonly_scope], resolver: @scope_resolver)
      end

      config do
        field(:calendar_id, :string, example: "primary")
        field(:channel_id, :string)
        field(:resource_id, :string)
        field(:token, :string)
      end

      signal do
        field(:channel_id, :string)
        field(:message_number, :string)
        field(:resource_id, :string)
        field(:resource_uri, :string)
        field(:resource_state, :string)
        field(:resource_type, :string)
        field(:resource_changed, :boolean)
        field(:calendar_id, :string)
        field(:channel_token, :string)
        field(:channel_expiration, :string)
        field(:payload_kind, :string)
        field(:delivery, :map)
      end
    end

    webhook :calendar_list_changed_push do
      id("google.calendar.calendar_list.changed.push")
      resource(:calendar)
      verb(:watch)
      data_classification(:personal_data)
      label("Calendar list changed push")
      description("Receive Google Calendar push notifications for CalendarList watch channels.")

      verification(%{
        kind: :google_calendar_channel,
        token: :host_verified,
        headers: :x_goog_channel
      })

      dedupe(%{key: [:channel_id, :resource_id, :message_number]})
      handler(Jido.Connect.Google.Calendar.Handlers.Triggers.CalendarChangedWebhook)

      access do
        auth(:user)
        scopes([@calendar_list_scope], resolver: @scope_resolver)
      end

      config do
        field(:channel_id, :string)
        field(:resource_id, :string)
        field(:token, :string)
      end

      signal do
        field(:channel_id, :string)
        field(:message_number, :string)
        field(:resource_id, :string)
        field(:resource_uri, :string)
        field(:resource_state, :string)
        field(:resource_type, :string)
        field(:resource_changed, :boolean)
        field(:calendar_id, :string)
        field(:channel_token, :string)
        field(:channel_expiration, :string)
        field(:payload_kind, :string)
        field(:delivery, :map)
      end
    end

    webhook :acl_changed_push do
      id("google.calendar.acl.changed.push")
      resource(:acl)
      verb(:watch)
      data_classification(:personal_data)
      label("ACL changed push")
      description("Receive Google Calendar push notifications for ACL watch channels.")

      verification(%{
        kind: :google_calendar_channel,
        token: :host_verified,
        headers: :x_goog_channel
      })

      dedupe(%{key: [:channel_id, :resource_id, :message_number]})
      handler(Jido.Connect.Google.Calendar.Handlers.Triggers.CalendarChangedWebhook)

      access do
        auth(:user)
        scopes([@acl_readonly_scope], resolver: @scope_resolver)
      end

      config do
        field(:calendar_id, :string, example: "primary")
        field(:channel_id, :string)
        field(:resource_id, :string)
        field(:token, :string)
      end

      signal do
        field(:channel_id, :string)
        field(:message_number, :string)
        field(:resource_id, :string)
        field(:resource_uri, :string)
        field(:resource_state, :string)
        field(:resource_type, :string)
        field(:resource_changed, :boolean)
        field(:calendar_id, :string)
        field(:channel_token, :string)
        field(:channel_expiration, :string)
        field(:payload_kind, :string)
        field(:delivery, :map)
      end
    end

    webhook :setting_changed_push do
      id("google.calendar.setting.changed.push")
      resource(:setting)
      verb(:watch)
      data_classification(:personal_data)
      label("Setting changed push")
      description("Receive Google Calendar push notifications for settings watch channels.")

      verification(%{
        kind: :google_calendar_channel,
        token: :host_verified,
        headers: :x_goog_channel
      })

      dedupe(%{key: [:channel_id, :resource_id, :message_number]})
      handler(Jido.Connect.Google.Calendar.Handlers.Triggers.CalendarChangedWebhook)

      access do
        auth(:user)
        scopes([@settings_readonly_scope], resolver: @scope_resolver)
      end

      config do
        field(:channel_id, :string)
        field(:resource_id, :string)
        field(:token, :string)
      end

      signal do
        field(:channel_id, :string)
        field(:message_number, :string)
        field(:resource_id, :string)
        field(:resource_uri, :string)
        field(:resource_state, :string)
        field(:resource_type, :string)
        field(:resource_changed, :boolean)
        field(:calendar_id, :string)
        field(:channel_token, :string)
        field(:channel_expiration, :string)
        field(:payload_kind, :string)
        field(:delivery, :map)
      end
    end
  end
end
