defmodule Jido.Connect.Intercom.WebhookTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Intercom.Webhook

  describe "verify_signature/2" do
    test "returns :ok when signatures match" do
      secret = "test-webhook-secret"
      body = ~s({"topic":"conversation.user.created"})
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

  describe "normalize_event/1 — conversation topics" do
    test "normalizes conversation.user.created event" do
      payload = fixture!("webhook_conversation_created.json")

      assert {:ok, signal} = Webhook.normalize_event(payload)
      assert signal.topic == "conversation.user.created"
      assert signal.change_type == "created"
      assert signal.delivery_id == "delivery-001"
      assert signal.conversation_id == "401"
      assert signal.conversation_state == "open"
      assert signal.conversation_title == "Need help with API integration"
      assert signal.conversation_body == "I'm having trouble integrating the REST API."
      assert signal.conversation_delivered_as == "customer_initiated"
      assert signal.author_id == "661240"
      assert signal.author_type == "contact"
      assert signal.app_id == "app-123"
      assert signal.created_at == 1_718_496_000
    end

    test "normalizes conversation.admin.replied event" do
      payload = fixture!("webhook_admin_replied.json")

      assert {:ok, signal} = Webhook.normalize_event(payload)
      assert signal.topic == "conversation.admin.replied"
      assert signal.change_type == "admin_replied"
      assert signal.delivery_id == "delivery-002"
      assert signal.conversation_id == "401"
      assert signal.conversation_state == "open"
      assert signal.app_id == "app-123"
    end

    test "normalizes conversation.user.replied event" do
      payload = fixture!("webhook_user_replied.json")

      assert {:ok, signal} = Webhook.normalize_event(payload)
      assert signal.topic == "conversation.user.replied"
      assert signal.change_type == "user_replied"
      assert signal.conversation_id == "401"
      assert signal.conversation_body == "Thanks for the help!"
      assert signal.author_id == "661240"
      assert signal.author_type == "contact"
    end

    test "normalizes conversation.admin.assigned event" do
      payload = fixture!("webhook_conversation_assigned.json")

      assert {:ok, signal} = Webhook.normalize_event(payload)
      assert signal.topic == "conversation.admin.assigned"
      assert signal.change_type == "assigned"
      assert signal.conversation_id == "401"
      assert signal.conversation_state == "open"
    end

    test "normalizes conversation.admin.closed event" do
      payload = fixture!("webhook_conversation_closed.json")

      assert {:ok, signal} = Webhook.normalize_event(payload)
      assert signal.topic == "conversation.admin.closed"
      assert signal.change_type == "closed"
      assert signal.conversation_id == "401"
      assert signal.conversation_state == "closed"
    end
  end

  describe "normalize_event/1 — contact topics" do
    test "normalizes contact.created event" do
      payload = fixture!("webhook_contact_created.json")

      assert {:ok, signal} = Webhook.normalize_event(payload)
      assert signal.topic == "contact.created"
      assert signal.change_type == "created"
      assert signal.delivery_id == "delivery-003"
      assert signal.contact_id == "661240"
      assert signal.contact_name == "Alice Nakamura"
      assert signal.contact_email == "alice@example.com"
      assert signal.app_id == "app-123"
      assert signal.created_at == 1_717_804_800
    end

    test "normalizes contact.updated event" do
      payload = fixture!("webhook_contact_updated.json")

      assert {:ok, signal} = Webhook.normalize_event(payload)
      assert signal.topic == "contact.updated"
      assert signal.change_type == "updated"
      assert signal.contact_id == "661240"
      assert signal.contact_name == "Alice Nakamura-Updated"
      assert signal.contact_email == "alice-updated@example.com"
    end

    test "normalizes contact.deleted event" do
      payload = fixture!("webhook_contact_deleted.json")

      assert {:ok, signal} = Webhook.normalize_event(payload)
      assert signal.topic == "contact.deleted"
      assert signal.change_type == "deleted"
      assert signal.contact_id == "661240"
      refute Map.has_key?(signal, :contact_name)
      refute Map.has_key?(signal, :contact_email)
    end
  end

  describe "normalize_event/1 — error cases" do
    test "returns error for unsupported topic" do
      payload = %{"topic" => "conversation.admin.nonsense"}

      assert {:error, %{reason: :unsupported_webhook_topic}} =
               Webhook.normalize_event(payload)
    end

    test "returns error for non-map payload" do
      assert {:error, %{reason: :invalid_webhook_event}} = Webhook.normalize_event("not a map")
    end

    test "returns error for missing topic" do
      assert {:error, %{reason: :invalid_webhook_event}} = Webhook.normalize_event(%{})
    end
  end

  describe "normalize_events/1" do
    test "normalizes a batch of events" do
      events = [
        fixture!("webhook_conversation_created.json"),
        fixture!("webhook_contact_created.json")
      ]

      assert {:ok, signals} = Webhook.normalize_events(events)
      assert length(signals) == 2

      topics = Enum.map(signals, & &1.topic) |> Enum.sort()
      assert topics == ["contact.created", "conversation.user.created"]
    end

    test "returns error for invalid event in batch" do
      events = [%{"topic" => "invalid.topic"}]

      assert {:error, %{reason: :unsupported_webhook_topic}} =
               Webhook.normalize_events(events)
    end

    test "returns error for non-list payload" do
      assert {:error, %{reason: :invalid_webhook_events}} =
               Webhook.normalize_events("not a list")
    end
  end

  describe "change_type/1" do
    test "maps conversation topics to change types" do
      assert Webhook.change_type("conversation.user.created") == "created"
      assert Webhook.change_type("conversation.admin.replied") == "admin_replied"
      assert Webhook.change_type("conversation.user.replied") == "user_replied"
      assert Webhook.change_type("conversation.admin.assigned") == "assigned"
      assert Webhook.change_type("conversation.admin.closed") == "closed"
    end

    test "maps contact topics to change types" do
      assert Webhook.change_type("contact.created") == "created"
      assert Webhook.change_type("contact.updated") == "updated"
      assert Webhook.change_type("contact.deleted") == "deleted"
    end

    test "returns unknown for unrecognized topics" do
      assert Webhook.change_type("unknown.topic") == "unknown"
    end
  end

  describe "conversation_id/1" do
    test "extracts conversation ID" do
      payload = fixture!("webhook_conversation_created.json")
      assert Webhook.conversation_id(payload) == "401"
    end

    test "returns nil for non-conversation payload" do
      assert Webhook.conversation_id(%{}) == nil
    end
  end

  describe "contact_id/1" do
    test "extracts contact ID" do
      payload = fixture!("webhook_contact_created.json")
      assert Webhook.contact_id(payload) == "661240"
    end

    test "returns nil for non-contact payload" do
      assert Webhook.contact_id(%{}) == nil
    end
  end

  describe "supported_topics/0" do
    test "returns all supported topics" do
      topics = Webhook.supported_topics()

      assert "conversation.user.created" in topics
      assert "conversation.admin.replied" in topics
      assert "conversation.user.replied" in topics
      assert "conversation.admin.assigned" in topics
      assert "conversation.admin.closed" in topics
      assert "contact.created" in topics
      assert "contact.updated" in topics
      assert "contact.deleted" in topics
      assert length(topics) == 8
    end
  end

  describe "conversation_topics/0 and contact_topics/0" do
    test "conversation_topics returns 5 conversation topics" do
      topics = Webhook.conversation_topics()
      assert length(topics) == 5
    end

    test "contact_topics returns 3 contact topics" do
      topics = Webhook.contact_topics()
      assert length(topics) == 3
    end
  end

  defp fixture!(name) do
    Path.join([__DIR__, "..", "..", "fixtures", "intercom", name])
    |> Path.expand()
    |> File.read!()
    |> Jason.decode!()
  end
end
