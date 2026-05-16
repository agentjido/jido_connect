defmodule Jido.Connect.Calendly.WebhookTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Calendly.Webhook

  describe "verify_signature/2" do
    test "returns :ok when signatures match" do
      key = "test-signing-key"
      body = ~s({"event":"invitee.created","payload":{}})
      computed = Webhook.compute_signature(body, key)

      assert :ok == Webhook.verify_signature(computed, computed)
    end

    test "returns error when signatures do not match" do
      assert {:error, %{reason: :webhook_signature_mismatch}} =
               Webhook.verify_signature("abc123", "def456")
    end

    test "returns error when signature is nil" do
      assert {:error, %{reason: :webhook_signature_missing}} =
               Webhook.verify_signature(nil, nil)
    end
  end

  describe "compute_signature/2" do
    test "produces deterministic HMAC-SHA256 hex digest" do
      digest = Webhook.compute_signature("body", "secret")

      assert digest ==
               :crypto.mac(:hmac, :sha256, "secret", "body")
               |> Base.encode16(case: :lower)
    end
  end

  describe "normalize_event/1 — invitee.created" do
    test "normalizes invitee created event" do
      payload = fixture!("webhook_invitee_created.json")

      assert {:ok, signal} = Webhook.normalize_event(payload)
      assert signal.event_type == "invitee.created"
      assert signal.change_type == "created"

      assert signal.invitee_uri ==
               "https://api.calendly.com/scheduled_events/m3n4o5p6/invitees/q7r8s9t0"

      assert signal.invitee_email == "bob@example.com"
      assert signal.invitee_name == "Bob Guest"
      assert signal.invitee_status == "active"
      assert signal.invitee_timezone == "America/New_York"
      assert signal.event_uri == "https://api.calendly.com/scheduled_events/m3n4o5p6"
      assert signal.event_type_uri == "https://api.calendly.com/event_types/i9j0k1l2"
      assert signal.event_type_name == "30 Minute Meeting"
      assert signal.organization_uri == "https://api.calendly.com/organizations/e5f6g7h8"
      assert signal.cancel_url == "https://calendly.com/cancellations/q7r8s9t0"
      assert signal.reschedule_url == "https://calendly.com/rescheds/q7r8s9t0"
      assert length(signal.questions_and_answers) == 1
      assert signal.created_at == "2026-05-18T08:15:00.000000Z"
      assert signal.updated_at == "2026-05-18T08:15:00.000000Z"
      assert signal.time == "2026-05-18T08:15:00.000000Z"
    end

    test "invitee created signal does not include cancellation fields" do
      payload = fixture!("webhook_invitee_created.json")

      assert {:ok, signal} = Webhook.normalize_event(payload)
      refute Map.has_key?(signal, :canceled_by)
      refute Map.has_key?(signal, :cancellation_reason)
    end
  end

  describe "normalize_event/1 — invitee.canceled" do
    test "normalizes invitee canceled event" do
      payload = fixture!("webhook_invitee_canceled.json")

      assert {:ok, signal} = Webhook.normalize_event(payload)
      assert signal.event_type == "invitee.canceled"
      assert signal.change_type == "canceled"

      assert signal.invitee_uri ==
               "https://api.calendly.com/scheduled_events/m3n4o5p6/invitees/q7r8s9t0"

      assert signal.invitee_email == "bob@example.com"
      assert signal.invitee_name == "Bob Guest"
      assert signal.invitee_status == "canceled"
      assert signal.invitee_timezone == "America/New_York"
      assert signal.event_uri == "https://api.calendly.com/scheduled_events/m3n4o5p6"
      assert signal.event_type_uri == "https://api.calendly.com/event_types/i9j0k1l2"
      assert signal.event_type_name == "30 Minute Meeting"
      assert signal.organization_uri == "https://api.calendly.com/organizations/e5f6g7h8"
      assert signal.canceled_by == "alice@example.com"
      assert signal.cancellation_reason == "Schedule conflict"
      assert signal.cancel_url == "https://calendly.com/cancellations/q7r8s9t0"
      assert signal.reschedule_url == "https://calendly.com/rescheds/q7r8s9t0"
      assert length(signal.questions_and_answers) == 1
      assert signal.created_at == "2026-05-18T08:15:00.000000Z"
      assert signal.updated_at == "2026-05-19T12:00:00.000000Z"
      assert signal.time == "2026-05-19T12:00:00.000000Z"
    end
  end

  describe "normalize_event/1 — error cases" do
    test "returns error for unsupported event type" do
      payload = %{"event" => "routing_form_submission.created", "payload" => %{}}

      assert {:error, %{reason: :unsupported_webhook_event}} =
               Webhook.normalize_event(payload)
    end

    test "returns error for non-map payload" do
      assert {:error, %{reason: :invalid_webhook_event}} =
               Webhook.normalize_event("not a map")
    end

    test "returns error for map without event" do
      assert {:error, %{reason: :invalid_webhook_event}} = Webhook.normalize_event(%{})
    end

    test "returns error for payload that is not a map" do
      assert {:error, %{reason: :invalid_webhook_event}} =
               Webhook.normalize_event(%{"event" => "invitee.created", "payload" => "not a map"})
    end

    test "returns error for empty map" do
      assert {:error, %{reason: :invalid_webhook_event}} = Webhook.normalize_event(%{})
    end
  end

  describe "normalize_events/1" do
    test "normalizes a batch of invitee events" do
      events = fixture!("webhook_batch_events.json")

      assert {:ok, signals} = Webhook.normalize_events(events)
      assert length(signals) == 3

      event_types = Enum.map(signals, & &1.event_type)
      assert Enum.count(event_types, &(&1 == "invitee.created")) == 2
      assert Enum.count(event_types, &(&1 == "invitee.canceled")) == 1
    end

    test "returns error for invalid event in batch" do
      events = [%{"event" => "unknown.event", "payload" => %{}}]

      assert {:error, %{reason: :unsupported_webhook_event}} =
               Webhook.normalize_events(events)
    end

    test "returns error for non-list payload" do
      assert {:error, %{reason: :invalid_webhook_events}} =
               Webhook.normalize_events("not a list")
    end
  end

  describe "invitee_uri/1" do
    test "extracts invitee URI from payload" do
      assert Webhook.invitee_uri(%{
               "payload" => %{
                 "uri" => "https://api.calendly.com/scheduled_events/ev1/invitees/inv1"
               }
             }) ==
               "https://api.calendly.com/scheduled_events/ev1/invitees/inv1"
    end

    test "returns nil for payload without nested payload" do
      assert Webhook.invitee_uri(%{}) == nil
    end
  end

  describe "supported_events/0" do
    test "returns list of supported Calendly webhook event types" do
      events = Webhook.supported_events()

      assert "invitee.created" in events
      assert "invitee.canceled" in events
      refute "routing_form_submission.created" in events
    end
  end

  defp fixture!(name) do
    Path.join([__DIR__, "..", "..", "..", "test", "fixtures", "calendly", name])
    |> Path.expand()
    |> File.read!()
    |> Jason.decode!()
  end
end
