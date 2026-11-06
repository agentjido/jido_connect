defmodule Jido.Connect.Jira.WebhookTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Jira.{CapturedDelivery, Webhook}
  alias Jido.Connect.TestSupport.LiveSmoke
  alias Jido.Connect.WebhookDelivery

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
    test "normalizes a captured issue creation" do
      payload = CapturedDelivery.payload!("issue_created")

      assert {:ok, signal} = Webhook.normalize_event(payload)
      assert signal.event_type == "jira:issue_created"
      assert signal.change_type == "created"
      assert signal.issue_event_type_name == "issue_created"
      assert signal.actor_id == "account-1"
      assert signal.actor_name == "Person 1"
      assert signal.issue_id == "46154"
      assert signal.issue_key == "JCL-59"
      assert signal.project_key == "JCL"
      assert signal.project_name == "Jido Connect Live"
      assert signal.summary == "JCL capture run 2026-10-30 19:34 UTC"
      assert signal.issue_type_name == "Task"
      assert signal.status_name == "Backlog"
      assert signal.priority_name == "Medium"
      assert signal.labels == []
      assert signal.assigned == true
      assert signal.assignee_id == "account-1"
      assert signal.assignee_name == "Person 1"
      assert signal.reporter_id == "account-1"
      assert signal.reporter_name == "Person 1"
      assert signal.created_at == "2026-10-30T20:34:46.505+0100"
      assert signal.updated_at == "2026-10-30T20:34:46.505+0100"
      assert signal.timestamp == "2026-10-30T19:34:47.074Z"
      refute Map.has_key?(signal, :matched_webhook_ids)
      refute Map.has_key?(signal, :webhook_id)

      assert %{id: "283376", items: items} = signal.changelog

      assert Enum.map(items, &{&1.field, &1.field_id}) == [
               {"Status", "status"},
               {"priority", "priority"},
               {"summary", "summary"},
               {"assignee", "assignee"},
               {"reporter", "reporter"}
             ]
    end
  end

  describe "captured deliveries" do
    test "replay through verify_delivery/4 with the signal of normalize_event/1" do
      assert [_, _, _, _, _, _, _, _, _] = names = CapturedDelivery.names()

      for name <- names do
        payload = CapturedDelivery.payload!(name)
        assert {:ok, signal} = Webhook.normalize_event(payload)

        assert {:ok, %WebhookDelivery{event: event, delivery_id: id, normalized_signal: ^signal}} =
                 LiveSmoke.replay(CapturedDelivery.path(name), webhook: Webhook)

        assert event == payload["webhookEvent"]
        assert id =~ ~r/^\d+$/
      end
    end
  end

  describe "public delivery map" do
    test "keeps the from and to values of assignment, status and due-date changes" do
      # Compared with each delivery's own changelog rather than literals, so
      # the test holds when the captures are sanitized again; the test below
      # and issue_signal_test.exs pin the values.
      for name <- ~w(assignee_set assignee_changed assignee_cleared status_changed
                     duedate_moved duedate_cleared) do
        %{"changelog" => changelog} = CapturedDelivery.payload!(name)

        assert {:ok, delivery} = LiveSmoke.replay(CapturedDelivery.path(name), webhook: Webhook)

        assert WebhookDelivery.to_public_map(delivery).normalized_signal["changelog"] == %{
                 "id" => changelog["id"],
                 "items" => Enum.map(changelog["items"], &public_item/1)
               }
      end
    end

    test "shows a status change with its status IDs and names" do
      assert {:ok, delivery} =
               LiveSmoke.replay(CapturedDelivery.path("status_changed"), webhook: Webhook)

      assert %{
               "id" => "283380",
               "items" => [
                 %{
                   "field_id" => "status",
                   "from" => "10916",
                   "from_string" => "Backlog",
                   "to" => "3",
                   "to_string" => "In Progress"
                 }
               ]
             } = WebhookDelivery.to_public_map(delivery).normalized_signal["changelog"]
    end

    test "cuts a changelog value over 512 bytes, which the signal keeps whole" do
      # Derived: the captured status change with `toString` repeated to 600 bytes.
      long = String.duplicate("In Progress ", 50)

      payload =
        update_in(CapturedDelivery.payload!("status_changed"), ["changelog", "items"], fn [item] ->
          [Map.put(item, "toString", long)]
        end)

      raw = Jason.encode!(payload)
      headers = %{"x-hub-signature" => sign(raw, LiveSmoke.replay_secret())}

      assert {:ok, %WebhookDelivery{normalized_signal: signal} = delivery} =
               Webhook.verify_delivery(raw, headers, LiveSmoke.replay_secret())

      assert [%{to_string: ^long}] = signal.changelog.items

      assert %{"items" => [%{"to" => "3", "to_string" => public}]} =
               WebhookDelivery.to_public_map(delivery).normalized_signal["changelog"]

      assert byte_size(long) == 600
      assert public == binary_part(long, 0, 512) <> "...[truncated 88 bytes]"
    end
  end

  describe "normalize_events/1" do
    test "normalizes a batch of events" do
      events = Enum.map(~w(issue_created comment_created), &CapturedDelivery.payload!/1)

      assert {:ok, [%{event_type: "jira:issue_created"}, %{event_type: "comment_created"}]} =
               Webhook.normalize_events(events)
    end

    test "returns error for invalid event in batch" do
      # Derived: the captured creation under an event name the triggers do not normalize.
      event = Map.put(CapturedDelivery.payload!("issue_created"), "webhookEvent", "unknown_event")

      assert {:error, %{reason: :unsupported_webhook_event}} =
               Webhook.normalize_events([event])
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
      assert Webhook.timestamp_to_iso8601(1_747_324_800_000) == "2025-05-15T16:00:00.000Z"
    end

    test "converts string epoch millis to ISO 8601" do
      assert Webhook.timestamp_to_iso8601("1747324800000") == "2025-05-15T16:00:00.000Z"
    end

    test "returns nil for nil input" do
      assert Webhook.timestamp_to_iso8601(nil) == nil
    end

    test "returns nil for unparseable string" do
      assert Webhook.timestamp_to_iso8601("not-a-number") == nil
      assert Webhook.timestamp_to_iso8601("1747324800000ms") == nil
    end

    test "returns nil for a signed string, which is not a string of digits" do
      assert Webhook.timestamp_to_iso8601("-5") == nil
      assert Webhook.timestamp_to_iso8601("+1747324800000") == nil
    end

    test "returns nil instead of raising for an epoch beyond the DateTime range" do
      assert Webhook.timestamp_to_iso8601(10 ** 20) == nil
      assert Webhook.timestamp_to_iso8601("100000000000000000000") == nil
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

  # The signal's names for the keys of a changelog item in a Jira delivery.
  defp public_item(item) do
    %{
      "field" => item["field"],
      "field_id" => item["fieldId"],
      "field_type" => item["fieldtype"],
      "from" => item["from"],
      "from_string" => item["fromString"],
      "to" => item["to"],
      "to_string" => item["toString"]
    }
  end

  defp sign(body, secret),
    do: "sha256=" <> (:hmac |> :crypto.mac(:sha256, secret, body) |> Base.encode16(case: :lower))
end
