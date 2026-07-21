defmodule Jido.Connect.Calendly.Handlers.Triggers.InviteeCanceledWebhookTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Calendly.Handlers.Triggers.InviteeCanceledWebhook

  test "normalizes invitee.canceled payload via Webhook module" do
    payload = %{
      "event" => "invitee.canceled",
      "time" => "2026-05-19T12:00:00.000000Z",
      "payload" => %{
        "uri" => "https://api.calendly.com/scheduled_events/ev1/invitees/inv1",
        "email" => "bob@example.com",
        "name" => "Bob Guest",
        "status" => "canceled",
        "timezone" => "America/New_York",
        "event" => "https://api.calendly.com/scheduled_events/ev1",
        "event_type" => "https://api.calendly.com/event_types/et1",
        "event_type_name" => "30 Minute Meeting",
        "organization" => "https://api.calendly.com/organizations/org1",
        "canceled_by" => "alice@example.com",
        "cancellation_reason" => "Schedule conflict",
        "questions_and_answers" => [],
        "created_at" => "2026-05-18T08:15:00.000000Z",
        "updated_at" => "2026-05-19T12:00:00.000000Z"
      }
    }

    assert {:ok, signal} = InviteeCanceledWebhook.run(payload, nil)
    assert signal.event_type == "invitee.canceled"
    assert signal.change_type == "canceled"
    assert signal.canceled_by == "alice@example.com"
    assert signal.cancellation_reason == "Schedule conflict"
  end

  test "returns error for invalid payload" do
    assert {:error, %{reason: :invalid_webhook_event}} = InviteeCanceledWebhook.run(%{}, nil)
  end
end
