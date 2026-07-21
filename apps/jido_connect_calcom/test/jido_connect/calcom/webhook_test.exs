defmodule Jido.Connect.Calcom.WebhookTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.{Error, WebhookDelivery}
  alias Jido.Connect.Calcom.Webhook

  # ---------------------------------------------------------------------------
  # Signature verification
  # ---------------------------------------------------------------------------

  test "verifies valid Cal.com HMAC-SHA256 signature" do
    body = booking_webhook_body("BOOKING_CREATED", "booking-1")
    secret = "whsec_test_secret"
    signature = cal_signature(secret, body)

    assert :ok =
             Webhook.verify_signature(
               body,
               %{"x-cal-signature-256" => signature},
               secret
             )
  end

  test "rejects signature when secret is missing" do
    body = "{}"
    headers = %{"x-cal-signature-256" => "bad"}

    assert {:error, %Error.AuthError{reason: :missing_webhook_secret}} =
             Webhook.verify_signature(body, headers, nil)

    assert {:error, %Error.AuthError{reason: :missing_webhook_secret}} =
             Webhook.verify_signature(body, headers, "")
  end

  test "rejects signature when header is missing" do
    body = "{}"

    assert {:error, %Error.AuthError{reason: :missing_signature}} =
             Webhook.verify_signature(body, %{}, "secret")
  end

  test "rejects invalid signature" do
    body = "{}"

    assert {:error, %Error.AuthError{reason: :invalid_signature}} =
             Webhook.verify_signature(body, %{"x-cal-signature-256" => "bad"}, "secret")
  end

  # ---------------------------------------------------------------------------
  # Request / delivery verification
  # ---------------------------------------------------------------------------

  test "verifies signed request and returns decoded payload" do
    body = booking_webhook_body("BOOKING_CREATED", "booking-1")
    secret = "whsec_test_secret"
    signature = cal_signature(secret, body)

    assert {:ok, %{"triggerEvent" => "BOOKING_CREATED"}} =
             Webhook.verify_request(body, %{"x-cal-signature-256" => signature}, secret)
  end

  test "verifies delivery with normalized signal" do
    body = booking_webhook_body("BOOKING_CREATED", "booking-1")
    secret = "whsec_test_secret"
    signature = cal_signature(secret, body)

    assert {:ok,
            %WebhookDelivery{
              provider: :calcom,
              delivery_id: "booking-1",
              event: "BOOKING_CREATED",
              signature_state: :verified,
              duplicate?: false,
              payload: %{"triggerEvent" => "BOOKING_CREATED"},
              normalized_signal: %{
                trigger_event: "BOOKING_CREATED",
                booking_uid: "booking-1"
              }
            }} =
             Webhook.verify_delivery(body, %{"x-cal-signature-256" => signature}, secret)
  end

  test "verifies delivery and detects duplicate" do
    body = booking_webhook_body("BOOKING_CREATED", "booking-1")
    secret = "whsec_test_secret"
    signature = cal_signature(secret, body)

    assert {:ok, %WebhookDelivery{duplicate?: true}} =
             Webhook.verify_delivery(
               body,
               %{"x-cal-signature-256" => signature},
               secret,
               seen_delivery_ids: ["booking-1"]
             )
  end

  test "rejects delivery with invalid JSON body" do
    body = "not json"
    secret = "whsec_test_secret"
    signature = cal_signature(secret, body)

    assert {:error, %Error.ProviderError{provider: :calcom, reason: :invalid_payload}} =
             Webhook.verify_delivery(body, %{"x-cal-signature-256" => signature}, secret)
  end

  test "rejects delivery with invalid signature" do
    body = "{}"

    assert {:error, %Error.AuthError{reason: :invalid_signature}} =
             Webhook.verify_delivery(body, %{"x-cal-signature-256" => "bad"}, "secret")
  end

  # ---------------------------------------------------------------------------
  # Event normalization
  # ---------------------------------------------------------------------------

  test "normalizes BOOKING_CREATED event signal" do
    payload =
      booking_event_payload("BOOKING_CREATED", "booking-1", %{
        "uid" => "booking-1",
        "title" => "Team Sync",
        "status" => "ACCEPTED",
        "startTime" => "2026-06-01T10:00:00Z",
        "endTime" => "2026-06-01T10:30:00Z",
        "duration" => 30,
        "location" => "https://meet.example.com/abc",
        "eventTypeId" => 5
      })

    assert {:ok,
            %{
              trigger_event: "BOOKING_CREATED",
              booking_uid: "booking-1",
              title: "Team Sync",
              status: "ACCEPTED",
              start: "2026-06-01T10:00:00Z",
              end: "2026-06-01T10:30:00Z",
              duration: 30,
              location: "https://meet.example.com/abc",
              event_type_id: 5
            }} = Webhook.normalize_signal("BOOKING_CREATED", payload)
  end

  test "normalizes BOOKING_UPDATED event signal" do
    payload =
      booking_event_payload("BOOKING_UPDATED", "booking-2", %{
        "uid" => "booking-2",
        "title" => "Updated Sync",
        "status" => "ACCEPTED"
      })

    assert {:ok,
            %{trigger_event: "BOOKING_UPDATED", booking_uid: "booking-2", title: "Updated Sync"}} =
             Webhook.normalize_signal("BOOKING_UPDATED", payload)
  end

  test "normalizes BOOKING_CANCELLED event signal with cancellation reason" do
    payload =
      booking_event_payload("BOOKING_CANCELLED", "booking-3", %{
        "uid" => "booking-3",
        "title" => "Cancelled Sync",
        "status" => "CANCELLED",
        "cancellationReason" => "conflict"
      })

    assert {:ok,
            %{
              trigger_event: "BOOKING_CANCELLED",
              booking_uid: "booking-3",
              status: "CANCELLED",
              cancellation_reason: "conflict"
            }} = Webhook.normalize_signal("BOOKING_CANCELLED", payload)
  end

  test "normalizes BOOKING_RESCHEDULED event signal with rescheduling reason" do
    payload =
      booking_event_payload("BOOKING_RESCHEDULED", "booking-4", %{
        "uid" => "booking-4",
        "title" => "Rescheduled Sync",
        "status" => "ACCEPTED",
        "startTime" => "2026-06-02T14:00:00Z",
        "reschedulingReason" => "schedule change"
      })

    assert {:ok,
            %{
              trigger_event: "BOOKING_RESCHEDULED",
              booking_uid: "booking-4",
              start: "2026-06-02T14:00:00Z",
              rescheduling_reason: "schedule change"
            }} = Webhook.normalize_signal("BOOKING_RESCHEDULED", payload)
  end

  test "rejects unsupported event types" do
    assert {:error, %Error.ProviderError{provider: :calcom, reason: :unsupported_event}} =
             Webhook.normalize_signal("UNKNOWN_EVENT", %{})
  end

  test "normalizes event via normalize_event/1" do
    payload =
      booking_event_payload("BOOKING_CREATED", "booking-5", %{
        "uid" => "booking-5",
        "title" => "Test Booking"
      })

    assert {:ok, %{trigger_event: "BOOKING_CREATED", booking_uid: "booking-5"}} =
             Webhook.normalize_event(payload)
  end

  test "normalize_event rejects payload without triggerEvent" do
    assert {:error, %Error.ProviderError{provider: :calcom, reason: :unsupported_event}} =
             Webhook.normalize_event(%{"type" => "other"})
  end

  test "normalizes delivery with delivery metadata" do
    delivery =
      WebhookDelivery.verified!(:calcom, %{
        delivery_id: "booking-6",
        event: "BOOKING_CREATED",
        payload:
          booking_event_payload("BOOKING_CREATED", "booking-6", %{
            "uid" => "booking-6",
            "title" => "Delivery Test"
          })
      })

    assert {:ok,
            %{
              trigger_event: "BOOKING_CREATED",
              booking_uid: "booking-6",
              delivery: %{
                provider: :calcom,
                event: "BOOKING_CREATED",
                duplicate?: false
              }
            }} = Webhook.normalize_signal(delivery)
  end

  test "handles booking event without nested payload key" do
    payload = %{
      "triggerEvent" => "BOOKING_CREATED",
      "uid" => "booking-flat",
      "title" => "Flat Payload"
    }

    assert {:ok, %{trigger_event: "BOOKING_CREATED", booking_uid: "booking-flat"}} =
             Webhook.normalize_signal("BOOKING_CREATED", payload)
  end

  # ---------------------------------------------------------------------------
  # Replay-safe fixture helpers
  # ---------------------------------------------------------------------------

  defp cal_signature(secret, body) do
    :crypto.mac(:hmac, :sha256, secret, body)
    |> Base.encode16(case: :lower)
  end

  defp booking_webhook_body(trigger_event, booking_uid) do
    Jason.encode!(%{
      "triggerEvent" => trigger_event,
      "createdAt" => "2026-05-15T12:00:00.000Z",
      "payload" => %{
        "uid" => booking_uid,
        "title" => "Test Booking",
        "status" => "ACCEPTED"
      }
    })
  end

  defp booking_event_payload(trigger_event, booking_uid, booking_attrs) do
    %{
      "triggerEvent" => trigger_event,
      "createdAt" => "2026-05-15T12:00:00.000Z",
      "payload" => Map.merge(%{"uid" => booking_uid}, booking_attrs)
    }
  end
end
