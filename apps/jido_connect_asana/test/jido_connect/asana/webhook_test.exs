defmodule Jido.Connect.Asana.WebhookTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Asana.Webhook

  describe "verify_signature/2" do
    test "returns :ok when signatures match" do
      secret = "webhook_secret_value"
      body = ~s({"events":[]})
      computed = Webhook.compute_signature(body, secret)
      assert :ok = Webhook.verify_signature(computed, computed)
    end

    test "returns error when signatures do not match" do
      assert {:error, _error} = Webhook.verify_signature("abc123", "def456")
    end

    test "returns error for non-binary inputs" do
      assert {:error, _error} = Webhook.verify_signature(nil, "sig")
      assert {:error, _error} = Webhook.verify_signature("sig", nil)
    end
  end

  describe "compute_signature/2" do
    test "computes HMAC-SHA256 hex digest" do
      sig = Webhook.compute_signature("body", "secret")

      assert is_binary(sig)
      assert byte_size(sig) == 64
    end
  end

  describe "normalize_event/1" do
    test "normalizes a valid event payload" do
      assert {:ok, signal} =
               Webhook.normalize_event(%{
                 "resource" => %{
                   "gid" => "998877",
                   "name" => "Design new landing page",
                   "resource_type" => "task"
                 },
                 "action" => "changed",
                 "user" => %{
                   "gid" => "123456",
                   "name" => "Alice Nakamura"
                 },
                 "created_at" => "2026-05-18T14:30:00.000Z"
               })

      assert signal.resource_gid == "998877"
      assert signal.resource_type == "task"
      assert signal.action == "changed"
      assert signal.change_type == "updated"
      assert signal.user_gid == "123456"
      assert signal.user_name == "Alice Nakamura"
      assert signal.occurred_at == "2026-05-18T14:30:00.000Z"
    end

    test "maps action strings to change types" do
      for {action, expected} <- [
            {"changed", "updated"},
            {"added", "created"},
            {"deleted", "deleted"}
          ] do
        assert {:ok, signal} =
                 Webhook.normalize_event(%{
                   "resource" => %{"gid" => "1", "resource_type" => "task"},
                   "action" => action
                 })

        assert signal.change_type == expected
      end
    end

    test "returns error for missing resource gid" do
      assert {:error, _error} =
               Webhook.normalize_event(%{
                 "resource" => %{"name" => "no gid"},
                 "action" => "changed"
               })
    end

    test "returns error for non-map payloads" do
      assert {:error, _error} = Webhook.normalize_event("not a map")
      assert {:error, _error} = Webhook.normalize_event(nil)
    end
  end

  describe "normalize_events/1" do
    test "normalizes a list of events" do
      events = [
        %{
          "resource" => %{"gid" => "1", "resource_type" => "task"},
          "action" => "changed"
        },
        %{
          "resource" => %{"gid" => "2", "resource_type" => "project"},
          "action" => "added"
        }
      ]

      assert {:ok, signals} = Webhook.normalize_events(events)
      assert length(signals) == 2
    end

    test "returns error when any event is invalid" do
      events = [
        %{"resource" => %{"gid" => "1"}, "action" => "changed"},
        %{"resource" => %{}, "action" => "changed"}
      ]

      assert {:error, _error} = Webhook.normalize_events(events)
    end

    test "returns error for non-list input" do
      assert {:error, _error} = Webhook.normalize_events("not a list")
    end
  end
end
