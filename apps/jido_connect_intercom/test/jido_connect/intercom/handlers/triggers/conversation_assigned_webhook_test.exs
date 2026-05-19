defmodule Jido.Connect.Intercom.Handlers.Triggers.ConversationAssignedWebhookTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Intercom.Handlers.Triggers.ConversationAssignedWebhook

  describe "normalize_signal/1" do
    test "delegates to Webhook.normalize_event for conversation.admin.assigned" do
      delivery = fixture!("webhook_conversation_assigned.json")

      assert {:ok, signal} = ConversationAssignedWebhook.normalize_signal(delivery)
      assert signal.topic == "conversation.admin.assigned"
      assert signal.change_type == "assigned"
      assert signal.conversation_id == "401"
      assert signal.conversation_state == "open"
    end
  end

  defp fixture!(name) do
    Path.join([__DIR__, "..", "..", "..", "..", "fixtures", "intercom", name])
    |> Path.expand()
    |> File.read!()
    |> Jason.decode!()
  end
end
