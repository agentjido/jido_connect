defmodule Jido.Connect.Intercom.Handlers.Triggers.UserRepliedWebhookTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Intercom.Handlers.Triggers.UserRepliedWebhook

  describe "normalize_signal/1" do
    test "delegates to Webhook.normalize_event for conversation.user.replied" do
      delivery = fixture!("webhook_user_replied.json")

      assert {:ok, signal} = UserRepliedWebhook.normalize_signal(delivery)
      assert signal.topic == "conversation.user.replied"
      assert signal.change_type == "user_replied"
      assert signal.conversation_id == "401"
      assert signal.conversation_body == "Thanks for the help!"
    end
  end

  defp fixture!(name) do
    Path.join([__DIR__, "..", "..", "..", "..", "fixtures", "intercom", name])
    |> Path.expand()
    |> File.read!()
    |> Jason.decode!()
  end
end
