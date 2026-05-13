defmodule Jido.Connect.Google.Drive.WebhookTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Drive.Webhook
  alias Jido.Connect.WebhookDelivery

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
end
