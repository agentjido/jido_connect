defmodule Jido.Connect.Calcom.Webhook.Normalizer do
  @moduledoc false

  alias Jido.Connect.{Data, Error, WebhookDelivery}
  alias Jido.Connect.Calcom.Normalizer, as: CalcomNormalizer

  @booking_events ~w(BOOKING_CREATED BOOKING_UPDATED BOOKING_CANCELLED BOOKING_RESCHEDULED)

  @spec normalize_signal(WebhookDelivery.t()) ::
          {:ok, map()} | {:error, Error.ProviderError.t()}
  def normalize_signal(%WebhookDelivery{event: event, payload: payload} = delivery) do
    with {:ok, signal} <- normalize_signal(event, payload) do
      {:ok, Map.put(signal, :delivery, delivery_metadata(delivery))}
    end
  end

  @spec normalize_signal(String.t() | nil, map()) ::
          {:ok, map()} | {:error, Error.ProviderError.t()}
  def normalize_signal(event, payload)
      when event in @booking_events do
    booking_data = Data.get(payload, "payload", payload)

    with {:ok, booking} <- CalcomNormalizer.booking(booking_data) do
      signal =
        Data.compact(%{
          trigger_event: event,
          booking_uid: Data.get(booking_data, "uid"),
          booking_id: Data.get(booking_data, "id"),
          title: booking.title,
          status: booking.status,
          start: booking.start,
          end: booking.end,
          duration: booking.duration,
          location: booking.location,
          event_type_id: booking.event_type_id,
          cancellation_reason: booking.cancellation_reason,
          rescheduling_reason: booking.rescheduling_reason,
          metadata: booking.metadata
        })

      {:ok, signal}
    end
  end

  def normalize_signal(_event, _payload) do
    {:error,
     Error.provider("Unsupported Cal.com webhook event",
       provider: :calcom,
       reason: :unsupported_event
     )}
  end

  @spec normalize_event(map()) ::
          {:ok, map()} | {:error, Error.ProviderError.t()}
  def normalize_event(%{"triggerEvent" => event} = payload) do
    normalize_signal(event, payload)
  end

  def normalize_event(_payload) do
    {:error,
     Error.provider("Unsupported Cal.com webhook event",
       provider: :calcom,
       reason: :unsupported_event
     )}
  end

  @spec maybe_put_normalized_signal(WebhookDelivery.t()) :: WebhookDelivery.t()
  def maybe_put_normalized_signal(%WebhookDelivery{} = delivery) do
    case normalize_signal(delivery) do
      {:ok, signal} -> WebhookDelivery.put_signal(delivery, signal)
      {:error, _reason} -> delivery
    end
  end

  defp delivery_metadata(%WebhookDelivery{} = delivery) do
    Data.compact(%{
      provider: delivery.provider,
      event: delivery.event,
      id: delivery.delivery_id,
      duplicate?: delivery.duplicate?,
      received_at: delivery.received_at
    })
  end
end
