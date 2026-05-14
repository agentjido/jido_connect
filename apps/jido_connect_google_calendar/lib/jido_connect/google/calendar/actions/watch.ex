defmodule Jido.Connect.Google.Calendar.Actions.Watch do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @calendar_list_scope "https://www.googleapis.com/auth/calendar.calendarlist.readonly"
  @events_readonly_scope "https://www.googleapis.com/auth/calendar.events.readonly"
  @acl_readonly_scope "https://www.googleapis.com/auth/calendar.acls.readonly"
  @settings_readonly_scope "https://www.googleapis.com/auth/calendar.settings.readonly"
  @scope_resolver Jido.Connect.Google.Calendar.ScopeResolver
  @channel_types ["web_hook", "webhook"]

  actions do
    action :watch_events do
      id("google.calendar.event.watch")
      resource(:event)
      verb(:watch)
      data_classification(:personal_data)
      label("Watch events")
      description("Create or renew a Google Calendar push notification channel for events.")
      handler(Jido.Connect.Google.Calendar.Handlers.Actions.WatchEvents)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@events_readonly_scope], resolver: @scope_resolver)
      end

      input do
        field(:calendar_id, :string, required?: true, example: "primary")

        field(:channel_id, :string,
          required?: true,
          description:
            "Unique channel id, usually a UUID, with a maximum length of 64 characters."
        )

        field(:address, :string,
          required?: true,
          description: "HTTPS webhook URL that receives Google Calendar push notifications."
        )

        field(:channel_type, :string, default: "web_hook", enum: @channel_types)
        field(:token, :string, description: "Opaque channel token echoed in webhook headers.")
        field(:expiration_ms, :integer, description: "Requested Unix timestamp in milliseconds.")
        field(:ttl_seconds, :integer, description: "Requested channel time-to-live in seconds.")
        field(:delivery_params, :map)
        field(:event_types, {:array, :string})
      end

      output do
        field(:channel, :map)
      end
    end

    action :watch_calendar_list do
      id("google.calendar.calendar_list.watch")
      resource(:calendar)
      verb(:watch)
      data_classification(:personal_data)
      label("Watch calendar list")
      description("Create or renew a Google Calendar push notification channel for CalendarList.")
      handler(Jido.Connect.Google.Calendar.Handlers.Actions.WatchCalendarList)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@calendar_list_scope], resolver: @scope_resolver)
      end

      input do
        field(:channel_id, :string,
          required?: true,
          description:
            "Unique channel id, usually a UUID, with a maximum length of 64 characters."
        )

        field(:address, :string,
          required?: true,
          description: "HTTPS webhook URL that receives Google Calendar push notifications."
        )

        field(:channel_type, :string, default: "web_hook", enum: @channel_types)
        field(:token, :string, description: "Opaque channel token echoed in webhook headers.")
        field(:expiration_ms, :integer, description: "Requested Unix timestamp in milliseconds.")
        field(:ttl_seconds, :integer, description: "Requested channel time-to-live in seconds.")
        field(:delivery_params, :map)
      end

      output do
        field(:channel, :map)
      end
    end

    action :watch_acl do
      id("google.calendar.acl.watch")
      resource(:acl)
      verb(:watch)
      data_classification(:personal_data)
      label("Watch ACL")
      description("Create or renew a Google Calendar push notification channel for ACL changes.")
      handler(Jido.Connect.Google.Calendar.Handlers.Actions.WatchAcl)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@acl_readonly_scope], resolver: @scope_resolver)
      end

      input do
        field(:calendar_id, :string, required?: true, example: "primary")

        field(:channel_id, :string,
          required?: true,
          description:
            "Unique channel id, usually a UUID, with a maximum length of 64 characters."
        )

        field(:address, :string,
          required?: true,
          description: "HTTPS webhook URL that receives Google Calendar push notifications."
        )

        field(:channel_type, :string, default: "web_hook", enum: @channel_types)
        field(:token, :string, description: "Opaque channel token echoed in webhook headers.")
        field(:expiration_ms, :integer, description: "Requested Unix timestamp in milliseconds.")
        field(:ttl_seconds, :integer, description: "Requested channel time-to-live in seconds.")
        field(:delivery_params, :map)
      end

      output do
        field(:channel, :map)
      end
    end

    action :watch_settings do
      id("google.calendar.settings.watch")
      resource(:setting)
      verb(:watch)
      data_classification(:personal_data)
      label("Watch settings")
      description("Create or renew a Google Calendar push notification channel for settings.")
      handler(Jido.Connect.Google.Calendar.Handlers.Actions.WatchSettings)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@settings_readonly_scope], resolver: @scope_resolver)
      end

      input do
        field(:channel_id, :string,
          required?: true,
          description:
            "Unique channel id, usually a UUID, with a maximum length of 64 characters."
        )

        field(:address, :string,
          required?: true,
          description: "HTTPS webhook URL that receives Google Calendar push notifications."
        )

        field(:channel_type, :string, default: "web_hook", enum: @channel_types)
        field(:token, :string, description: "Opaque channel token echoed in webhook headers.")
        field(:expiration_ms, :integer, description: "Requested Unix timestamp in milliseconds.")
        field(:ttl_seconds, :integer, description: "Requested channel time-to-live in seconds.")
        field(:delivery_params, :map)
      end

      output do
        field(:channel, :map)
      end
    end

    action :stop_channel do
      id("google.calendar.channel.stop")
      resource(:channel)
      verb(:delete)
      data_classification(:personal_data)
      label("Stop Calendar channel")
      description("Stop Google Calendar push notification delivery for a watched channel.")
      handler(Jido.Connect.Google.Calendar.Handlers.Actions.StopChannel)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@events_readonly_scope], resolver: @scope_resolver)
      end

      input do
        field(:channel_id, :string, required?: true)
        field(:resource_id, :string, required?: true)
      end

      output do
        field(:result, :map)
      end
    end
  end
end
