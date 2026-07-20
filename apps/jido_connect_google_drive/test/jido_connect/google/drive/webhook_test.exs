defmodule Jido.Connect.Google.Drive.WebhookTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.{Error, WebhookDelivery}
  alias Jido.Connect.Google.Drive.Webhook

  @headers %{
    "x-goog-channel-id" => "channel123",
    "x-goog-channel-token" => "secret",
    "x-goog-channel-expiration" => "Wed, 13 May 2026 12:00:00 GMT",
    "x-goog-resource-id" => "resource123",
    "x-goog-resource-uri" => "https://www.googleapis.com/drive/v3/files/file123",
    "x-goog-resource-state" => "update",
    "x-goog-message-number" => "7",
    "x-goog-changed" => "content,parents"
  }

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

  test "normalizes collection changes push as a lightweight refresh signal" do
    headers = [
      {"x-goog-channel-id", "channel-123"},
      {"x-goog-message-number", "11"},
      {"x-goog-resource-id", "resource-123"},
      {"x-goog-resource-state", "change"},
      {"x-goog-resource-uri", "https://www.googleapis.com/drive/v3/changes"}
    ]

    assert {:ok,
            %{
              collection_changed?: true,
              channel_id: "channel-123",
              resource_id: "resource-123",
              message_number: "11",
              resource_state: "change"
            } = signal} =
             Jido.Connect.Google.Drive.Handlers.Triggers.CollectionChangesWebhook.normalize_channel_notification(
               headers,
               %{"kind" => "drive#changes"}
             )

    refute Map.has_key?(signal, :file_id)
  end

  test "does not report the initial collection sync notification as a change" do
    headers = [
      {"x-goog-channel-id", "channel-123"},
      {"x-goog-message-number", "1"},
      {"x-goog-resource-id", "resource-123"},
      {"x-goog-resource-state", "sync"},
      {"x-goog-resource-uri", "https://www.googleapis.com/drive/v3/changes"}
    ]

    assert {:ok, %{collection_changed?: false, resource_state: "sync"}} =
             Jido.Connect.Google.Drive.Handlers.Triggers.CollectionChangesWebhook.normalize_channel_notification(
               headers
             )
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

  test "parses Google Drive webhook headers" do
    assert %{
             channel_id: "channel123",
             channel_token: "secret",
             resource_id: "resource123",
             resource_state: "update",
             message_number: "7",
             changed: "content,parents"
           } = Webhook.parse_headers(@headers)
  end

  test "parses list-style request headers" do
    assert %{
             channel_id: "channel123",
             channel_token: "secret",
             resource_id: "resource123"
           } = Webhook.parse_headers(Map.to_list(@headers))

    assert {:ok, %WebhookDelivery{delivery_id: "channel123:7"}} =
             @headers
             |> Map.to_list()
             |> Webhook.verify_delivery("secret")
  end

  test "verifies token and normalizes delivery" do
    assert {:ok, %WebhookDelivery{} = delivery} = Webhook.verify_delivery(@headers, "secret")

    assert delivery.provider == :google_drive
    assert delivery.event == "update"
    assert delivery.delivery_id == "channel123:7"
    assert delivery.signature_state == :verified

    assert %{
             channel_id: "channel123",
             resource_id: "resource123",
             channel_token_present: true,
             changed: ["content", "parents"],
             file_id: "file123",
             resource_changed: true,
             delivery: %{id: "channel123:7"}
           } = delivery.normalized_signal

    refute Map.has_key?(delivery.normalized_signal, :channel_token)
    refute Map.has_key?(delivery.metadata, :channel_token)

    public = WebhookDelivery.to_public_map(delivery)
    assert public.headers["x-goog-channel-token"] == "[redacted]"
  end

  test "rejects invalid channel token" do
    assert {:error, %Jido.Connect.Error.AuthError{reason: :invalid_token}} =
             Webhook.verify_delivery(@headers, "different")
  end

  test "does not mark delivery verified when no expected token is configured" do
    assert {:error, %Jido.Connect.Error.AuthError{reason: :missing_expected_token}} =
             Webhook.verify_delivery(@headers, nil)
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
