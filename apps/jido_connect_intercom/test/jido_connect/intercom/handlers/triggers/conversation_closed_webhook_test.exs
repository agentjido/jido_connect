defmodule Jido.Connect.Intercom.Handlers.Triggers.ConversationClosedWebhookTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Intercom.Handlers.Triggers.ConversationClosedWebhook

  describe "normalize_signal/1" do
    test "delegates to Webhook.normalize_event for conversation.admin.closed" do
      delivery = fixture!("webhook_conversation_closed.json")

      assert {:ok, signal} = ConversationClosedWebhook.normalize_signal(delivery)
      assert signal.topic == "conversation.admin.closed"
      assert signal.change_type == "closed"
      assert signal.conversation_id == "401"
      assert signal.conversation_state == "closed"
    end
  end

  defp fixture!(name) do
    Path.join([__DIR__, "..", "..", "..", "..", "fixtures", "intercom", name])
    |> Path.expand()
    |> File.read!()
    |> Jason.decode!()
  end
end
