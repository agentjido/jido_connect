defmodule Jido.Connect.Calendly.Handlers.Triggers.InviteeCreatedWebhookTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Calendly.Handlers.Triggers.InviteeCreatedWebhook

  test "normalizes invitee.created payload via Webhook module" do
    payload = %{
      "event" => "invitee.created",
      "time" => "2026-05-18T08:15:00.000000Z",
      "payload" => %{
        "uri" => "https://api.calendly.com/scheduled_events/ev1/invitees/inv1",
        "email" => "bob@example.com",
        "name" => "Bob Guest",
        "status" => "active",
        "timezone" => "America/New_York",
        "event" => "https://api.calendly.com/scheduled_events/ev1",
        "event_type" => "https://api.calendly.com/event_types/et1",
        "event_type_name" => "30 Minute Meeting",
        "organization" => "https://api.calendly.com/organizations/org1",
        "questions_and_answers" => [],
        "created_at" => "2026-05-18T08:15:00.000000Z",
        "updated_at" => "2026-05-18T08:15:00.000000Z"
      }
    }

    assert {:ok, signal} = InviteeCreatedWebhook.run(payload, nil)
    assert signal.event_type == "invitee.created"
    assert signal.change_type == "created"
    assert signal.invitee_email == "bob@example.com"
    assert signal.invitee_name == "Bob Guest"
  end

  test "returns error for invalid payload" do
    assert {:error, %{reason: :invalid_webhook_event}} = InviteeCreatedWebhook.run(%{}, nil)
  end
end
