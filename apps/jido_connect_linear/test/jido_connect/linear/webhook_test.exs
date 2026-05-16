defmodule Jido.Connect.Linear.WebhookTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Linear.Webhook

  describe "verify_signature/2" do
    test "returns :ok when signatures match" do
      secret = "test-signing-secret"
      body = ~s({"type":"Issue","action":"create"})
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
    test "produces deterministic HMAC-SHA256 base64 digest" do
      digest = Webhook.compute_signature("body", "secret")

      assert digest ==
               :crypto.mac(:hmac, :sha256, "secret", "body")
               |> Base.encode64()
    end
  end

  describe "normalize_event/1 — issue events" do
    test "normalizes issue created event" do
      payload = fixture!("webhook_issue_created.json")

      assert {:ok, signal} = Webhook.normalize_event(payload)
      assert signal.event_type == "Issue"
      assert signal.action == "create"
      assert signal.issue_id == "uuid-001"
      assert signal.identifier == "LIN-123"
      assert signal.team_id == "team-1"
      assert signal.team_key == "LIN"
      assert signal.title == "Implement user authentication flow"
      assert signal.status_name == "In Progress"
      assert signal.priority_label == "Medium"
      assert signal.assignee_id == "user-1"
      assert signal.assignee_name == "Alice Nakamura"
      assert signal.creator_id == "user-2"
      assert signal.creator_name == "Bob Martinez"
      assert signal.labels == ["backend", "auth"]
      assert signal.created_at == "2026-04-10T08:30:00.000Z"
      assert signal.updated_at == "2026-05-15T14:22:00.000Z"
      assert signal.webhook_id == "wh-42"
      assert signal.timestamp == "2026-05-15T14:22:00.000Z"
    end

    test "normalizes issue updated event" do
      payload = fixture!("webhook_issue_updated.json")

      assert {:ok, signal} = Webhook.normalize_event(payload)
      assert signal.event_type == "Issue"
      assert signal.action == "update"
      assert signal.identifier == "LIN-123"
      assert signal.status_name == "Done"
      assert signal.priority_label == "High"
      assert signal.labels == ["backend", "auth", "security"]
    end
  end

  describe "normalize_event/1 — comment events" do
    test "normalizes comment created event" do
      payload = fixture!("webhook_comment_created.json")

      assert {:ok, signal} = Webhook.normalize_event(payload)
      assert signal.event_type == "Comment"
      assert signal.action == "create"
      assert signal.comment_id == "comment-webhook-1"
      assert signal.comment_body == "This looks great, merging to main."
      assert signal.issue_id == "uuid-001"
      assert signal.issue_identifier == "LIN-123"
      assert signal.user_id == "user-1"
      assert signal.user_name == "Alice Nakamura"
      assert signal.created_at == "2026-05-15T16:00:00.000Z"
      assert signal.updated_at == "2026-05-15T16:00:00.000Z"
      assert signal.webhook_id == "wh-44"
      assert signal.timestamp == "2026-05-15T16:00:00.000Z"
    end

    test "normalizes comment updated event" do
      payload = fixture!("webhook_comment_updated.json")

      assert {:ok, signal} = Webhook.normalize_event(payload)
      assert signal.event_type == "Comment"
      assert signal.action == "update"
      assert signal.comment_id == "comment-webhook-1"
      assert signal.comment_body == "This looks great, merging to main after QA sign-off."
      assert signal.issue_id == "uuid-001"
      assert signal.issue_identifier == "LIN-123"
      assert signal.user_id == "user-1"
      assert signal.user_name == "Alice Nakamura"
      assert signal.updated_at == "2026-05-15T16:30:00.000Z"
      assert signal.webhook_id == "wh-45"
      assert signal.timestamp == "2026-05-15T16:30:00.000Z"
    end
  end

  describe "normalize_event/1 — error cases" do
    test "returns error for unsupported event type" do
      payload = %{"type" => "Reaction", "action" => "create", "data" => %{}}

      assert {:error, %{reason: :unsupported_webhook_event}} =
               Webhook.normalize_event(payload)
    end

    test "returns error for unsupported issue action" do
      payload = %{"type" => "Issue", "action" => "unknown", "data" => %{}}

      assert {:error, %{reason: :unsupported_webhook_action}} =
               Webhook.normalize_event(payload)
    end

    test "returns error for unsupported comment action" do
      payload = %{"type" => "Comment", "action" => "remove", "data" => %{}}

      assert {:error, %{reason: :unsupported_webhook_action}} =
               Webhook.normalize_event(payload)
    end

    test "returns error for missing data" do
      payload = %{"type" => "Issue", "action" => "create"}

      assert {:error, %{reason: :invalid_webhook_event}} = Webhook.normalize_event(payload)
    end

    test "returns error for non-map payload" do
      assert {:error, %{reason: :invalid_webhook_event}} = Webhook.normalize_event("not a map")
    end

    test "returns error for map without type" do
      assert {:error, %{reason: :invalid_webhook_event}} = Webhook.normalize_event(%{})
    end
  end

  describe "normalize_events/1" do
    test "normalizes a batch of issue and comment events" do
      events = fixture!("webhook_batch_events.json")

      assert {:ok, signals} = Webhook.normalize_events(events)
      assert length(signals) == 3

      event_types = Enum.map(signals, & &1.event_type)
      assert Enum.count(event_types, &(&1 == "Issue")) == 2
      assert Enum.count(event_types, &(&1 == "Comment")) == 1
    end

    test "returns error for invalid event in batch" do
      events = [%{"type" => "Unknown", "action" => "create"}]

      assert {:error, %{reason: :unsupported_webhook_event}} =
               Webhook.normalize_events(events)
    end

    test "returns error for non-list payload" do
      assert {:error, %{reason: :invalid_webhook_events}} =
               Webhook.normalize_events("not a list")
    end
  end

  describe "issue_identifier/1" do
    test "extracts issue identifier from payload" do
      assert Webhook.issue_identifier(%{"data" => %{"identifier" => "LIN-123"}}) == "LIN-123"
    end

    test "returns nil for payload without data" do
      assert Webhook.issue_identifier(%{}) == nil
    end
  end

  describe "supported_actions/0" do
    test "returns list of supported issue action types" do
      actions = Webhook.supported_actions()

      assert "create" in actions
      assert "update" in actions
      assert "remove" in actions
    end
  end

  describe "supported_comment_actions/0" do
    test "returns list of supported comment action types" do
      actions = Webhook.supported_comment_actions()

      assert "create" in actions
      assert "update" in actions
      refute "remove" in actions
    end
  end

  defp fixture!(name) do
    Path.join([__DIR__, "..", "..", "..", "test", "fixtures", "linear", name])
    |> Path.expand()
    |> File.read!()
    |> Jason.decode!()
  end
end
