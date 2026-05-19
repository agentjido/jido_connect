defmodule Jido.Connect.Intercom.Handlers.Triggers.ConversationCreatedWebhookTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Intercom.Handlers.Triggers.ConversationCreatedWebhook

  describe "normalize_signal/1" do
    test "delegates to Webhook.normalize_event for conversation.user.created" do
      delivery = %{
        "type" => "notification_event",
        "topic" => "conversation.user.created",
        "delivery_id" => "delivery-001",
        "delivery_attempt" => 1,
        "created_at" => 1_718_496_000,
        "app_id" => "app-123",
        "data" => %{
          "type" => "notification_event_data",
          "item" => %{
            "type" => "conversation",
            "id" => "401",
            "state" => "open",
            "source" => %{
              "type" => "conversation",
              "delivered_as" => "customer_initiated",
              "body" => "I need help",
              "author" => %{"type" => "contact", "id" => "661240"}
            }
          }
        }
      }

      assert {:ok, signal} = ConversationCreatedWebhook.normalize_signal(delivery)
      assert signal.topic == "conversation.user.created"
      assert signal.change_type == "created"
      assert signal.conversation_id == "401"
      assert signal.conversation_state == "open"
      assert signal.author_id == "661240"
    end

    test "returns error for invalid payload" do
      assert {:error, error} = ConversationCreatedWebhook.normalize_signal("not a map")
      assert error.reason == :invalid_webhook_event
    end
  end
end
