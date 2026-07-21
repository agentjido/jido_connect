defmodule Jido.Connect.Intercom.Handlers.Triggers.AdminRepliedWebhookTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Intercom.Handlers.Triggers.AdminRepliedWebhook

  describe "normalize_signal/1" do
    test "delegates to Webhook.normalize_event for conversation.admin.replied" do
      delivery = fixture!("webhook_admin_replied.json")

      assert {:ok, signal} = AdminRepliedWebhook.normalize_signal(delivery)
      assert signal.topic == "conversation.admin.replied"
      assert signal.change_type == "admin_replied"
      assert signal.conversation_id == "401"
      assert signal.conversation_state == "open"
      assert signal.delivery_id == "delivery-002"
    end
  end

  defp fixture!(name) do
    Path.join([__DIR__, "..", "..", "..", "..", "fixtures", "intercom", name])
    |> Path.expand()
    |> File.read!()
    |> Jason.decode!()
  end
end
