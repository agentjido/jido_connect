defmodule Jido.Connect.HubSpot.WebhookTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.HubSpot.Webhook

  describe "verify_signature/2" do
    test "returns :ok when signatures match" do
      secret = "test-client-secret"
      body = ~s({"eventId":"1001"})
      computed = Webhook.compute_signature(body, secret)

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

  describe "normalize_event/1" do
    test "normalizes contact property change event" do
      payload = fixture!("webhook_contact_updated.json")

      assert {:ok, signal} = Webhook.normalize_event(payload)
      assert signal.event_id == "1001"
      assert signal.subscription_id == "50"
      assert signal.portal_id == "123456"
      assert signal.object_id == "501"
      assert signal.object_type == "contact"
      assert signal.event_type == "contact.propertyChange"
      assert signal.change_type == "updated"
      assert signal.property_name == "lifecyclestage"
      assert signal.property_value == "customer"
      assert signal.change_source == "CRM_UI"
      assert signal.app_id == "99999"
      refute is_nil(signal.occurred_at)
    end

    test "normalizes contact creation event" do
      payload = fixture!("webhook_contact_created.json")

      assert {:ok, signal} = Webhook.normalize_event(payload)
      assert signal.object_type == "contact"
      assert signal.change_type == "created"
      refute Map.has_key?(signal, :property_name)
    end

    test "normalizes contact deletion event" do
      payload = fixture!("webhook_contact_deleted.json")

      assert {:ok, signal} = Webhook.normalize_event(payload)
      assert signal.object_type == "contact"
      assert signal.change_type == "deleted"
    end

    test "normalizes deal property change event" do
      payload = fixture!("webhook_deal_updated.json")

      assert {:ok, signal} = Webhook.normalize_event(payload)
      assert signal.object_id == "301"
      assert signal.object_type == "deal"
      assert signal.change_type == "updated"
      assert signal.property_name == "dealstage"
      assert signal.property_value == "closedwon"
    end

    test "normalizes deal creation event" do
      payload = fixture!("webhook_deal_created.json")

      assert {:ok, signal} = Webhook.normalize_event(payload)
      assert signal.object_type == "deal"
      assert signal.change_type == "created"
    end

    test "returns error for missing objectId" do
      payload = %{"eventId" => "999", "eventType" => "contact.creation"}

      assert {:error, %{reason: :invalid_webhook_event}} = Webhook.normalize_event(payload)
    end

    test "returns error for non-map payload" do
      assert {:error, %{reason: :invalid_webhook_event}} = Webhook.normalize_event("not a map")
    end
  end

  describe "normalize_events/1" do
    test "normalizes a batch of events" do
      events = fixture!("webhook_batch_events.json")

      assert {:ok, signals} = Webhook.normalize_events(events)
      assert length(signals) == 2

      types = Enum.map(signals, & &1.object_type) |> Enum.sort()
      assert types == ["contact", "deal"]
    end

    test "returns error for invalid event in batch" do
      events = [%{"eventId" => "999", "eventType" => "contact.creation"}]

      assert {:error, %{reason: :invalid_webhook_event}} = Webhook.normalize_events(events)
    end

    test "returns error for non-list payload" do
      assert {:error, %{reason: :invalid_webhook_events}} = Webhook.normalize_events("not a list")
    end
  end

  describe "occurred_at/1" do
    test "converts epoch millis to ISO 8601" do
      result = Webhook.occurred_at(%{"occurredAt" => 1_747_324_800_000})
      assert is_binary(result)
      assert String.ends_with?(result, "Z")
    end

    test "converts string epoch millis to ISO 8601" do
      result = Webhook.occurred_at(%{"occurredAt" => "1747324800000"})
      assert is_binary(result)
    end

    test "returns nil for missing occurredAt" do
      assert Webhook.occurred_at(%{}) == nil
    end
  end

  describe "object_type/1" do
    test "extracts contact object type" do
      assert Webhook.object_type(%{"eventType" => "contact.creation"}) == "contact"
    end

    test "extracts deal object type" do
      assert Webhook.object_type(%{"eventType" => "deal.propertyChange"}) == "deal"
    end

    test "extracts company object type" do
      assert Webhook.object_type(%{"eventType" => "company.deletion"}) == "company"
    end

    test "extracts ticket object type" do
      assert Webhook.object_type(%{"eventType" => "ticket.creation"}) == "ticket"
    end

    test "returns nil for unknown event type" do
      assert Webhook.object_type(%{"eventType" => "unknown.event"}) == nil
    end
  end

  defp fixture!(name) do
    Path.join([__DIR__, "..", "..", "fixtures", "hubspot", name])
    |> Path.expand()
    |> File.read!()
    |> Jason.decode!()
  end
end
