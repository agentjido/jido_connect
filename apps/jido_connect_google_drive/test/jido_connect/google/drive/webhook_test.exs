defmodule Jido.Connect.Google.Drive.WebhookTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.{Error, WebhookDelivery}
  alias Jido.Connect.Google.Drive.Webhook

  test "normalizes Drive channel notification headers from verified deliveries" do
    delivery =
      WebhookDelivery.verified!(:google,
        event: "google.drive.file.changed.push",
        delivery_id: "delivery-123",
        headers: %{
          "X-Goog-Channel-ID" => " channel-123 ",
          "X-Goog-Channel-Token" => "route=drive",
          "X-Goog-Channel-Expiration" => "Tue, 19 Nov 2030 01:13:52 GMT",
          "X-Goog-Resource-ID" => "resource-123",
          "X-Goog-Resource-URI" => "https://www.googleapis.com/drive/v3/files/file%20123",
          "X-Goog-Resource-State" => "update",
          "X-Goog-Changed" => "content, permissions",
          "X-Goog-Message-Number" => "10"
        },
        payload: %{}
      )

    assert {:ok,
            %{
              channel_id: "channel-123",
              channel_token: "route=drive",
              resource_id: "resource-123",
              resource_uri: "https://www.googleapis.com/drive/v3/files/file%20123",
              resource_state: "update",
              resource_changed: true,
              message_number: "10",
              changed: ["content", "permissions"],
              file_id: "file 123",
              delivery: %{provider: :google, event: "google.drive.file.changed.push"}
            }} = Webhook.normalize_signal(delivery)
  end

  test "normalizes changes notifications with payload kind" do
    headers = [
      {"x-goog-channel-id", "channel-123"},
      {"x-goog-message-number", "1"},
      {"x-goog-resource-id", "resource-123"},
      {"x-goog-resource-state", "sync"},
      {"x-goog-resource-uri", "https://www.googleapis.com/drive/v3/changes"}
    ]

    assert {:ok,
            %{
              channel_id: "channel-123",
              resource_state: "sync",
              resource_changed: false,
              changed: [],
              payload_kind: "drive#changes"
            }} = Webhook.normalize_channel_notification(headers, %{"kind" => "drive#changes"})
  end

  test "accepts string-keyed delivery maps" do
    assert {:ok,
            %{
              channel_id: "channel-123",
              resource_state: "change",
              payload_kind: "drive#changes"
            }} =
             Webhook.normalize_signal(%{
               "headers" => %{
                 "x-goog-channel-id" => "channel-123",
                 "x-goog-message-number" => "2",
                 "x-goog-resource-id" => "resource-123",
                 "x-goog-resource-state" => "change",
                 "x-goog-resource-uri" => "https://www.googleapis.com/drive/v3/changes"
               },
               "payload" => %{"kind" => "drive#changes"}
             })
  end

  test "rejects notifications missing required Google headers" do
    assert {:error,
            %Error.ProviderError{
              provider: :google,
              reason: :invalid_drive_channel_headers,
              details: %{missing_headers: missing}
            }} = Webhook.normalize_signal(%{"x-goog-channel-id" => "channel-123"})

    assert "x-goog-message-number" in missing
    assert "x-goog-resource-id" in missing
    assert "x-goog-resource-state" in missing
    assert "x-goog-resource-uri" in missing
  end
end
