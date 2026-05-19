defmodule Jido.Connect.Zendesk.WebhookTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Zendesk.Webhook

  describe "supported_events/0" do
    test "lists all supported event types" do
      events = Webhook.supported_events()

      assert "Ticket Created" in events
      assert "Ticket Updated" in events
      assert "Ticket Status Changed" in events
      assert "Comment Created" in events
    end
  end

  describe "verify_signature/2" do
    test "returns :ok when digests match" do
      secret = "test-shared-secret"
      body = ~s({"type":"Ticket Created"})
      computed = Webhook.compute_signature(body, secret)
      assert :ok = Webhook.verify_signature(computed, computed)
    end

    test "returns error when digests differ" do
      assert {:error, error} = Webhook.verify_signature("aaa", "bbb")
      assert error.reason == :webhook_signature_mismatch
    end

    test "returns error when signature is missing" do
      assert {:error, error} = Webhook.verify_signature(nil, nil)
      assert error.reason == :webhook_signature_missing
    end
  end

  describe "compute_signature/2" do
    test "computes HMAC-SHA256 base64 digest" do
      result = Webhook.compute_signature("body", "secret")
      assert is_binary(result)
      assert byte_size(result) > 0
    end
  end

  describe "normalize_event/1 — Ticket Created" do
    test "normalizes ticket created webhook" do
      payload = fixture!("webhook_ticket_created.json")

      assert {:ok, signal} = Webhook.normalize_event(payload)
      assert signal.event_type == "Ticket Created"
      assert signal.change_type == "created"
      assert signal.ticket_id == 12345
      assert signal.subject == "Cannot reset password"
      assert signal.status == "open"
      assert signal.priority == "normal"
      assert signal.type == "incident"
      assert signal.group_id == 101
      assert signal.assignee_id == 9001
      assert signal.requester_id == 9901
      assert signal.organization_id == 201
      assert signal.tags == ["password", "login", "urgent"]
      assert signal.webhook_id == "wh-invocation-001"
      assert signal.account_id == "example"
      refute Map.has_key?(signal, :previous)
    end
  end

  describe "normalize_event/1 — Ticket Updated" do
    test "normalizes ticket updated webhook with previous state" do
      payload = fixture!("webhook_ticket_updated.json")

      assert {:ok, signal} = Webhook.normalize_event(payload)
      assert signal.event_type == "Ticket Updated"
      assert signal.change_type == "updated"
      assert signal.ticket_id == 12345
      assert signal.status == "solved"
      assert signal.tags == ["password", "login", "urgent", "resolved"]
      assert signal.previous != nil
      assert signal.previous[:status] == "open"
      assert signal.previous[:assignee_id] == 9001
    end
  end

  describe "normalize_event/1 — Comment Created" do
    test "normalizes comment created webhook" do
      payload = fixture!("webhook_comment_created.json")

      assert {:ok, signal} = Webhook.normalize_event(payload)
      assert signal.event_type == "Comment Created"
      assert signal.change_type == "created"
      assert signal.comment_id == 50001
      assert signal.comment_body =~ "checked the email configuration"
      assert signal.comment_public == true
      assert signal.comment_author_id == 9001
      assert signal.ticket_id == 12345
      assert signal.ticket_subject == "Cannot reset password"
    end
  end

  describe "normalize_event/1 — error cases" do
    test "returns error for unsupported event type" do
      payload = %{"type" => "Unknown Event"}

      assert {:error, error} = Webhook.normalize_event(payload)
      assert error.reason == :unsupported_webhook_event
    end

    test "returns error for invalid payload" do
      assert {:error, error} = Webhook.normalize_event("not a map")
      assert error.reason == :invalid_webhook_event
    end

    test "returns error when ticket data is missing" do
      payload = %{"type" => "Ticket Created", "current" => nil, "ticket" => nil}

      assert {:error, error} = Webhook.normalize_event(payload)
      assert error.reason == :invalid_webhook_event
    end

    test "returns error when comment data is missing" do
      payload = %{
        "type" => "Comment Created",
        "ticket" => %{"id" => 1},
        "current" => nil
      }

      assert {:error, error} = Webhook.normalize_event(payload)
      assert error.reason == :invalid_webhook_event
    end

    test "returns error when ticket context is missing for comment" do
      payload = %{
        "type" => "Comment Created",
        "current" => %{"id" => 50001, "body" => "hello"},
        "ticket" => nil
      }

      assert {:error, error} = Webhook.normalize_event(payload)
      assert error.reason == :invalid_webhook_event
    end
  end

  describe "normalize_events/1" do
    test "normalizes a batch of webhook events" do
      events = fixture!("webhook_batch_events.json")

      assert {:ok, signals} = Webhook.normalize_events(events)
      assert length(signals) == 2

      assert Enum.at(signals, 0).event_type == "Ticket Created"
      assert Enum.at(signals, 0).change_type == "created"

      assert Enum.at(signals, 1).event_type == "Comment Created"
      assert Enum.at(signals, 1).change_type == "created"
    end

    test "returns error for non-list input" do
      assert {:error, error} = Webhook.normalize_events("not a list")
      assert error.reason == :invalid_webhook_events
    end

    test "returns error if any event is invalid" do
      events = [%{"type" => "Unknown"}, %{"type" => "Ticket Created"}]

      assert {:error, error} = Webhook.normalize_events(events)
      assert error.reason == :unsupported_webhook_event
    end
  end

  describe "ticket_id/1" do
    test "extracts ticket ID from ticket payload" do
      assert Webhook.ticket_id(%{"ticket" => %{"id" => 12345}}) == 12345
    end

    test "extracts ticket ID from current payload" do
      assert Webhook.ticket_id(%{"current" => %{"id" => 99}}) == 99
    end

    test "returns nil for other payloads" do
      assert Webhook.ticket_id(%{}) == nil
    end
  end

  describe "ticket_change_type/1" do
    test "maps event types to change types" do
      assert Webhook.ticket_change_type("Ticket Created") == "created"
      assert Webhook.ticket_change_type("Ticket Updated") == "updated"
      assert Webhook.ticket_change_type("Ticket Status Changed") == "status_changed"
      assert Webhook.ticket_change_type("Unknown") == "unknown"
    end
  end

  defp fixture!(name) do
    Path.join([__DIR__, "..", "..", "..", "test", "fixtures", "zendesk", name])
    |> Path.expand()
    |> File.read!()
    |> Jason.decode!()
  end
end
