defmodule Jido.Connect.Intercom.Handlers.Triggers.ContactUpdatedWebhookTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Intercom.Handlers.Triggers.ContactUpdatedWebhook

  describe "normalize_signal/1" do
    test "delegates to Webhook.normalize_event for contact.updated" do
      delivery = fixture!("webhook_contact_updated.json")

      assert {:ok, signal} = ContactUpdatedWebhook.normalize_signal(delivery)
      assert signal.topic == "contact.updated"
      assert signal.change_type == "updated"
      assert signal.contact_id == "661240"
      assert signal.contact_name == "Alice Nakamura-Updated"
      assert signal.contact_email == "alice-updated@example.com"
    end
  end

  defp fixture!(name) do
    Path.join([__DIR__, "..", "..", "..", "..", "fixtures", "intercom", name])
    |> Path.expand()
    |> File.read!()
    |> Jason.decode!()
  end
end
