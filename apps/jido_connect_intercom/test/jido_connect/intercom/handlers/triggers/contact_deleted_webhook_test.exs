defmodule Jido.Connect.Intercom.Handlers.Triggers.ContactDeletedWebhookTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Intercom.Handlers.Triggers.ContactDeletedWebhook

  describe "normalize_signal/1" do
    test "delegates to Webhook.normalize_event for contact.deleted" do
      delivery = fixture!("webhook_contact_deleted.json")

      assert {:ok, signal} = ContactDeletedWebhook.normalize_signal(delivery)
      assert signal.topic == "contact.deleted"
      assert signal.change_type == "deleted"
      assert signal.contact_id == "661240"
      refute Map.has_key?(signal, :contact_name)
    end
  end

  defp fixture!(name) do
    Path.join([__DIR__, "..", "..", "..", "..", "fixtures", "intercom", name])
    |> Path.expand()
    |> File.read!()
    |> Jason.decode!()
  end
end
