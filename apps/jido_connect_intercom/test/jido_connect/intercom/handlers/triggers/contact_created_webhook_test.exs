defmodule Jido.Connect.Intercom.Handlers.Triggers.ContactCreatedWebhookTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Intercom.Handlers.Triggers.ContactCreatedWebhook

  describe "normalize_signal/1" do
    test "delegates to Webhook.normalize_event for contact.created" do
      delivery = fixture!("webhook_contact_created.json")

      assert {:ok, signal} = ContactCreatedWebhook.normalize_signal(delivery)
      assert signal.topic == "contact.created"
      assert signal.change_type == "created"
      assert signal.contact_id == "661240"
      assert signal.contact_name == "Alice Nakamura"
      assert signal.contact_email == "alice@example.com"
    end
  end

  defp fixture!(name) do
    Path.join([__DIR__, "..", "..", "..", "..", "fixtures", "intercom", name])
    |> Path.expand()
    |> File.read!()
    |> Jason.decode!()
  end
end
