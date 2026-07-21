defmodule Jido.Connect.Zendesk.Handlers.Triggers.TicketChangedWebhookTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Zendesk.Handlers.Triggers.TicketChangedWebhook

  describe "normalize_signal/1" do
    test "delegates to Webhook.normalize_event for ticket created" do
      delivery = %{
        "type" => "Ticket Created",
        "id" => "wh-invocation-001",
        "account_id" => "example",
        "ticket" => %{
          "id" => 12345,
          "subject" => "Cannot reset password",
          "status" => "open",
          "priority" => "normal",
          "type" => "incident"
        },
        "current" => %{
          "id" => 12345,
          "subject" => "Cannot reset password",
          "status" => "open"
        },
        "timestamp" => "2026-03-15T10:30:00Z"
      }

      assert {:ok, signal} = TicketChangedWebhook.normalize_signal(delivery)
      assert signal.event_type == "Ticket Created"
      assert signal.change_type == "created"
      assert signal.ticket_id == 12345
      assert signal.subject == "Cannot reset password"
    end

    test "delegates to Webhook.normalize_event for ticket updated" do
      delivery = %{
        "type" => "Ticket Updated",
        "id" => "wh-invocation-002",
        "account_id" => "example",
        "ticket" => %{
          "id" => 12345,
          "subject" => "Cannot reset password",
          "status" => "solved"
        },
        "current" => %{
          "id" => 12345,
          "status" => "solved"
        },
        "previous" => %{
          "status" => "open",
          "updated_at" => "2026-03-15T10:30:00Z"
        },
        "timestamp" => "2026-03-16T09:00:00Z"
      }

      assert {:ok, signal} = TicketChangedWebhook.normalize_signal(delivery)
      assert signal.event_type == "Ticket Updated"
      assert signal.change_type == "updated"
      assert signal.ticket_id == 12345
      assert signal.previous != nil
      assert signal.previous[:status] == "open"
    end

    test "returns error for unsupported event type" do
      assert {:error, error} = TicketChangedWebhook.normalize_signal(%{"type" => "Unknown"})
      assert error.reason == :unsupported_webhook_event
    end

    test "returns error for invalid payload" do
      assert {:error, error} = TicketChangedWebhook.normalize_signal("not a map")
      assert error.reason == :invalid_webhook_event
    end
  end
end
