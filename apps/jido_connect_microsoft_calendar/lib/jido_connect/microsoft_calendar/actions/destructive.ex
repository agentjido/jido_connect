defmodule Jido.Connect.MicrosoftCalendar.Actions.Destructive do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @calendars_read_write "Calendars.ReadWrite"
  @scope_resolver Jido.Connect.MicrosoftCalendar.ScopeResolver

  actions do
    action :delete_event do
      id("microsoft.calendar.event.delete")
      resource(:event)
      verb(:delete)
      data_classification(:personal_data)
      label("Delete Microsoft Calendar event")
      description("Permanently delete a Microsoft Calendar event.")
      handler(Jido.Connect.MicrosoftCalendar.Handlers.Actions.DeleteEvent)
      effect(:destructive, confirmation: :always)

      access do
        auth(:user)
        scopes([@calendars_read_write], resolver: @scope_resolver)
      end

      input do
        field(:event_id, :string, required?: true, example: "AAMkAGI2...")
        field(:calendar_id, :string)
      end

      output do
        field(:deleted, :boolean)
        field(:event_id, :string)
      end
    end

    action :cancel_event do
      id("microsoft.calendar.event.cancel")
      resource(:event)
      verb(:delete)
      data_classification(:personal_data)
      label("Cancel Microsoft Calendar event")

      description(
        "Cancel a Microsoft Calendar event and send cancellation notices to attendees. Only the organizer can cancel."
      )

      handler(Jido.Connect.MicrosoftCalendar.Handlers.Actions.CancelEvent)
      effect(:destructive, confirmation: :always)

      access do
        auth(:user)
        scopes([@calendars_read_write], resolver: @scope_resolver)
      end

      input do
        field(:event_id, :string, required?: true, example: "AAMkAGI2...")
        field(:comment, :string)
      end

      output do
        field(:cancelled, :boolean)
        field(:event_id, :string)
      end
    end
  end
end
