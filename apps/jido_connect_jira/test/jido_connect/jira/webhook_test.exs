defmodule Jido.Connect.Jira.WebhookTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Jira.Webhook

  describe "verify_signature/2" do
    test "returns :ok when signatures match" do
      secret = "test-shared-secret"
      body = ~s({"webhookEvent":"jira:issue_created"})
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
      assert signal.event_type == "jira:issue_created"
      assert signal.change_type == "created"
      assert signal.issue_id == "10001"
      assert signal.issue_key == "PROJ-123"
      assert signal.project_key == "PROJ"
      assert signal.project_name == "Project Alpha"
      assert signal.summary == "Implement user authentication flow"
      assert signal.issue_type_name == "Task"
      assert signal.status_name == "To Do"
      assert signal.priority_name == "Medium"
      assert signal.labels == ["backend", "auth"]
      assert signal.assignee_id == "5f8a7b9c1d2e3f4a5b6c7d8e"
      assert signal.assignee_name == "Alice Nakamura"
      assert signal.reporter_id == "6g9b8c0d2e3f4a5b7c8d9e0f"
      assert signal.reporter_name == "Bob Martinez"
      assert signal.created_at == "2026-04-10T08:30:00.000+0000"
      assert signal.updated_at == "2026-05-15T14:22:00.000+0000"
      assert signal.webhook_id == "42"
      assert signal.timestamp == 1_747_324_800_000
      refute Map.has_key?(signal, :changelog)
    end

    test "normalizes issue updated event with changelog" do
      payload = fixture!("webhook_issue_updated.json")

      assert {:ok, signal} = Webhook.normalize_event(payload)
      assert signal.event_type == "jira:issue_updated"
      assert signal.change_type == "updated"
      assert signal.issue_key == "PROJ-123"
      assert signal.status_name == "In Progress"
      assert signal.priority_name == "High"
      assert signal.labels == ["backend", "auth", "security"]

      assert [%{field: "status"}, %{field: "priority"}] = signal.changelog.items

      status_change = Enum.find(signal.changelog.items, &(&1.field == "status"))
      assert status_change.from_string == "To Do"
      assert status_change.to_string == "In Progress"
    end
  end

  describe "normalize_event/1 — comment events" do
    test "normalizes comment created event" do
      payload = fixture!("webhook_comment_created.json")

      assert {:ok, signal} = Webhook.normalize_event(payload)
      assert signal.event_type == "comment_created"
      assert signal.change_type == "created"
      assert signal.comment_id == "20010"
      assert signal.comment_body == "Investigated the OAuth2 flow. Ready to start implementation."
      assert signal.comment_author_id == "5f8a7b9c1d2e3f4a5b6c7d8e"
      assert signal.comment_author_name == "Alice Nakamura"
      assert signal.comment_created_at == "2026-05-01T10:30:00.000+0000"
      assert signal.issue_id == "10001"
      assert signal.issue_key == "PROJ-123"
      assert signal.webhook_id == "43"
      assert signal.timestamp == 1_747_326_000_000
    end

    test "normalizes comment updated event" do
      payload = fixture!("webhook_comment_updated.json")

      assert {:ok, signal} = Webhook.normalize_event(payload)
      assert signal.event_type == "comment_updated"
      assert signal.change_type == "updated"
      assert signal.comment_id == "20010"

      assert signal.comment_body ==
               "Updated: investigated the OAuth2 flow. Implementation complete."

      assert signal.comment_updated_at == "2026-05-01T11:00:00.000+0000"
    end
  end

  describe "normalize_event/1 — error cases" do
    test "returns error for unsupported event type" do
      payload = %{"webhookEvent" => "jira:worklog_created"}

      assert {:error, %{reason: :unsupported_webhook_event}} =
               Webhook.normalize_event(payload)
    end

    test "returns error for missing issue in issue event" do
      payload = %{"webhookEvent" => "jira:issue_created"}

      assert {:error, %{reason: :invalid_webhook_event}} = Webhook.normalize_event(payload)
    end

    test "returns error for missing comment in comment event" do
      payload = %{"webhookEvent" => "comment_created", "issue" => %{"id" => "1"}}

      assert {:error, %{reason: :invalid_webhook_event}} = Webhook.normalize_event(payload)
    end

    test "returns error for missing issue in comment event" do
      payload = %{
        "webhookEvent" => "comment_created",
        "comment" => %{"id" => "1"}
      }

      assert {:error, %{reason: :invalid_webhook_event}} = Webhook.normalize_event(payload)
    end

    test "returns error for non-map payload" do
      assert {:error, %{reason: :invalid_webhook_event}} = Webhook.normalize_event("not a map")
    end

    test "returns error for map without webhookEvent" do
      assert {:error, %{reason: :invalid_webhook_event}} = Webhook.normalize_event(%{})
    end
  end

  describe "normalize_events/1" do
    test "normalizes a batch of events" do
      events = fixture!("webhook_batch_events.json")

      assert {:ok, signals} = Webhook.normalize_events(events)
      assert length(signals) == 2

      types = Enum.map(signals, & &1.event_type) |> Enum.sort()
      assert types == ["comment_created", "jira:issue_created"]
    end

    test "returns error for invalid event in batch" do
      events = [%{"webhookEvent" => "unknown_event"}]

      assert {:error, %{reason: :unsupported_webhook_event}} =
               Webhook.normalize_events(events)
    end

    test "returns error for non-list payload" do
      assert {:error, %{reason: :invalid_webhook_events}} =
               Webhook.normalize_events("not a list")
    end
  end

  describe "issue_key/1" do
    test "extracts issue key from payload" do
      assert Webhook.issue_key(%{"issue" => %{"key" => "PROJ-123"}}) == "PROJ-123"
    end

    test "returns nil for payload without issue" do
      assert Webhook.issue_key(%{}) == nil
    end
  end

  describe "issue_change_type/1" do
    test "returns created for issue_created" do
      assert Webhook.issue_change_type("jira:issue_created") == "created"
    end

    test "returns updated for issue_updated" do
      assert Webhook.issue_change_type("jira:issue_updated") == "updated"
    end

    test "returns unknown for other events" do
      assert Webhook.issue_change_type("other") == "unknown"
    end
  end

  describe "comment_change_type/1" do
    test "returns created for comment_created" do
      assert Webhook.comment_change_type("comment_created") == "created"
    end

    test "returns updated for comment_updated" do
      assert Webhook.comment_change_type("comment_updated") == "updated"
    end

    test "returns unknown for other events" do
      assert Webhook.comment_change_type("other") == "unknown"
    end
  end

  describe "timestamp_to_iso8601/1" do
    test "converts epoch millis to ISO 8601" do
      result = Webhook.timestamp_to_iso8601(1_747_324_800_000)
      assert is_binary(result)
      assert String.ends_with?(result, "Z")
    end

    test "converts string epoch millis to ISO 8601" do
      result = Webhook.timestamp_to_iso8601("1747324800000")
      assert is_binary(result)
    end

    test "returns nil for nil input" do
      assert Webhook.timestamp_to_iso8601(nil) == nil
    end

    test "returns nil for unparseable string" do
      assert Webhook.timestamp_to_iso8601("not-a-number") == nil
    end
  end

  describe "supported_events/0" do
    test "returns list of supported event types" do
      events = Webhook.supported_events()

      assert "jira:issue_created" in events
      assert "jira:issue_updated" in events
      assert "comment_created" in events
      assert "comment_updated" in events
    end
  end

  defp fixture!(name) do
    Path.join([__DIR__, "..", "..", "..", "test", "fixtures", "jira", name])
    |> Path.expand()
    |> File.read!()
    |> Jason.decode!()
  end
end
