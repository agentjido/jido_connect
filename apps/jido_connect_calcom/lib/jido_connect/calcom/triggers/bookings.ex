defmodule Jido.Connect.Calcom.Triggers.Bookings do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @scope_resolver Jido.Connect.Calcom.ScopeResolver

  triggers do
    webhook :booking_created do
      id("calcom.booking.created")
      resource(:booking)
      verb(:watch)
      data_classification(:personal_data)
      label("Booking created")

      description("Receive Cal.com webhook notifications when a new booking is created.")

      verification(%{
        kind: :calcom_hmac_sha256,
        signature_header: "x-cal-signature-256"
      })

      dedupe(%{key: [:booking_uid, :trigger_event]})
      handler(Jido.Connect.Calcom.Handlers.Triggers.BookingCreatedWebhook)

      access do
        auth(:api_key)
        scopes(["BOOKING_READ"], resolver: @scope_resolver)
      end

      config do
        field(:webhook_secret, :string)
      end

      signal do
        field(:trigger_event, :string)
        field(:booking_uid, :string)
        field(:booking_id, :integer)
        field(:title, :string)
        field(:status, :string)
        field(:start, :string)
        field(:end, :string)
        field(:duration, :integer)
        field(:location, :string)
        field(:event_type_id, :integer)
        field(:delivery, :map)
      end
    end

    webhook :booking_updated do
      id("calcom.booking.updated")
      resource(:booking)
      verb(:watch)
      data_classification(:personal_data)
      label("Booking updated")

      description("Receive Cal.com webhook notifications when a booking is updated.")

      verification(%{
        kind: :calcom_hmac_sha256,
        signature_header: "x-cal-signature-256"
      })

      dedupe(%{key: [:booking_uid, :trigger_event]})
      handler(Jido.Connect.Calcom.Handlers.Triggers.BookingUpdatedWebhook)

      access do
        auth(:api_key)
        scopes(["BOOKING_READ"], resolver: @scope_resolver)
      end

      config do
        field(:webhook_secret, :string)
      end

      signal do
        field(:trigger_event, :string)
        field(:booking_uid, :string)
        field(:booking_id, :integer)
        field(:title, :string)
        field(:status, :string)
        field(:start, :string)
        field(:end, :string)
        field(:duration, :integer)
        field(:location, :string)
        field(:event_type_id, :integer)
        field(:delivery, :map)
      end
    end

    webhook :booking_canceled do
      id("calcom.booking.canceled")
      resource(:booking)
      verb(:watch)
      data_classification(:personal_data)
      label("Booking canceled")

      description("Receive Cal.com webhook notifications when a booking is canceled.")

      verification(%{
        kind: :calcom_hmac_sha256,
        signature_header: "x-cal-signature-256"
      })

      dedupe(%{key: [:booking_uid, :trigger_event]})
      handler(Jido.Connect.Calcom.Handlers.Triggers.BookingCanceledWebhook)

      access do
        auth(:api_key)
        scopes(["BOOKING_READ"], resolver: @scope_resolver)
      end

      config do
        field(:webhook_secret, :string)
      end

      signal do
        field(:trigger_event, :string)
        field(:booking_uid, :string)
        field(:booking_id, :integer)
        field(:title, :string)
        field(:status, :string)
        field(:start, :string)
        field(:end, :string)
        field(:duration, :integer)
        field(:location, :string)
        field(:event_type_id, :integer)
        field(:cancellation_reason, :string)
        field(:delivery, :map)
      end
    end

    webhook :booking_rescheduled do
      id("calcom.booking.rescheduled")
      resource(:booking)
      verb(:watch)
      data_classification(:personal_data)
      label("Booking rescheduled")

      description("Receive Cal.com webhook notifications when a booking is rescheduled.")

      verification(%{
        kind: :calcom_hmac_sha256,
        signature_header: "x-cal-signature-256"
      })

      dedupe(%{key: [:booking_uid, :trigger_event]})
      handler(Jido.Connect.Calcom.Handlers.Triggers.BookingRescheduledWebhook)

      access do
        auth(:api_key)
        scopes(["BOOKING_READ"], resolver: @scope_resolver)
      end

      config do
        field(:webhook_secret, :string)
      end

      signal do
        field(:trigger_event, :string)
        field(:booking_uid, :string)
        field(:booking_id, :integer)
        field(:title, :string)
        field(:status, :string)
        field(:start, :string)
        field(:end, :string)
        field(:duration, :integer)
        field(:location, :string)
        field(:event_type_id, :integer)
        field(:rescheduling_reason, :string)
        field(:delivery, :map)
      end
    end
  end
end
