defmodule Jido.Connect.Google.Calendar.WebhookTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Calendar.Webhook
  alias Jido.Connect.Google.Calendar.Handlers.Triggers.CalendarChangedWebhook
  alias Jido.Connect.WebhookDelivery

  test "normalizes event channel headers" do
    assert {:ok, signal} =
             Webhook.normalize_channel_notification(%{
               "X-Goog-Channel-ID" => "event-channel",
               "X-Goog-Message-Number" => "10",
               "X-Goog-Resource-ID" => "events-resource",
               "X-Goog-Resource-State" => "exists",
               "X-Goog-Resource-URI" =>
                 "https://www.googleapis.com/calendar/v3/calendars/primary/events",
               "X-Goog-Channel-Token" => "tenant=1",
               "X-Goog-Channel-Expiration" => "Tue, 19 Nov 2026 01:13:52 GMT"
             })

    assert signal.channel_id == "event-channel"
    assert signal.message_number == "10"
    assert signal.resource_id == "events-resource"
    assert signal.resource_state == "exists"
    assert signal.resource_type == "event"
    assert signal.resource_changed
    assert signal.calendar_id == "primary"
    assert signal.channel_token == "tenant=1"
  end

  test "marks sync notifications as initialization only" do
    assert {:ok, signal} =
             Webhook.normalize_channel_notification([
               {"x-goog-channel-id", "calendar-list-channel"},
               {"x-goog-message-number", "1"},
               {"x-goog-resource-id", "calendar-list-resource"},
               {"x-goog-resource-state", "sync"},
               {
                 "x-goog-resource-uri",
                 "https://www.googleapis.com/calendar/v3/users/me/calendarList"
               }
             ])

    assert signal.resource_type == "calendar_list"
    refute signal.resource_changed
  end

  test "trigger handler delegates to webhook normalization" do
    assert {:ok, signal} =
             CalendarChangedWebhook.normalize_channel_notification(%{
               "x-goog-channel-id" => "settings-channel",
               "x-goog-message-number" => "3",
               "x-goog-resource-id" => "settings-resource",
               "x-goog-resource-state" => "exists",
               "x-goog-resource-uri" => "https://www.googleapis.com/calendar/v3/users/me/settings"
             })

    assert signal.channel_id == "settings-channel"
    assert signal.resource_type == "setting"
    assert signal.resource_changed
  end

  test "attaches delivery metadata from webhook envelopes" do
    delivery =
      WebhookDelivery.verified!(:google, %{
        event: "google.calendar.event.changed.push",
        delivery_id: "delivery-1",
        headers: %{
          "x-goog-channel-id" => "event-channel",
          "x-goog-message-number" => "11",
          "x-goog-resource-id" => "events-resource",
          "x-goog-resource-state" => "exists",
          "x-goog-resource-uri" =>
            "https://www.googleapis.com/calendar/v3/calendars/team%40example.com/events"
        }
      })

    assert {:ok, signal} = Webhook.normalize_signal(delivery)
    assert signal.calendar_id == "team@example.com"
    assert signal.delivery.provider == :google
    assert signal.delivery.event == "google.calendar.event.changed.push"
    assert signal.delivery.id == "delivery-1"
  end

  test "returns provider errors for missing required headers" do
    assert {:error,
            %Jido.Connect.Error.ProviderError{
              provider: :google,
              reason: :invalid_calendar_channel_headers,
              details: %{missing_headers: missing_headers}
            }} = Webhook.normalize_channel_notification(%{})

    assert "x-goog-channel-id" in missing_headers
    assert "x-goog-resource-uri" in missing_headers
  end
end
