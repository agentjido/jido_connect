defmodule Jido.Connect.Gmail.WebhookTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.{Error, WebhookDelivery}
  alias Jido.Connect.Gmail.Handlers.Triggers.MailboxChangedWebhook
  alias Jido.Connect.Gmail.Webhook

  test "normalizes Gmail Pub/Sub push payloads" do
    payload =
      pubsub_payload(%{
        "emailAddress" => "user@example.com",
        "historyId" => 126
      })

    assert {:ok,
            %{
              email_address: "user@example.com",
              history_id: "126",
              message_id: "pubsub-message-1",
              publish_time: "2026-05-14T12:00:00.000Z",
              subscription: "projects/project-1/subscriptions/gmail"
            }} = Webhook.normalize_pubsub_push(payload)

    assert {:ok, %{history_id: "126"}} = MailboxChangedWebhook.normalize_pubsub_push(payload)
  end

  test "normalizes Gmail webhook deliveries with delivery metadata" do
    delivery =
      WebhookDelivery.verified!(:google,
        event: "google.gmail.mailbox.changed",
        delivery_id: "pubsub-message-1",
        duplicate?: true,
        received_at: ~U[2026-05-14 12:00:01Z],
        payload:
          pubsub_payload(%{
            "emailAddress" => "user@example.com",
            "historyId" => "126"
          })
      )

    assert {:ok,
            %{
              history_id: "126",
              delivery: %{
                provider: :google,
                event: "google.gmail.mailbox.changed",
                id: "pubsub-message-1",
                duplicate?: true,
                received_at: ~U[2026-05-14 12:00:01Z]
              }
            }} = Webhook.normalize_signal(delivery)
  end

  test "rejects malformed Gmail Pub/Sub payloads" do
    assert {:error, %Error.ProviderError{provider: :google, reason: :invalid_pubsub_payload}} =
             Webhook.normalize_pubsub_push(%{})

    assert {:error, %Error.ProviderError{provider: :google, reason: :invalid_pubsub_data}} =
             Webhook.normalize_pubsub_push(%{"message" => %{"data" => "not base64"}})

    assert {:error, %Error.ProviderError{provider: :google, reason: :invalid_pubsub_data}} =
             Webhook.normalize_pubsub_push(
               pubsub_payload(%{"emailAddress" => "user@example.com"})
             )
  end

  defp pubsub_payload(data) do
    encoded =
      data
      |> Jason.encode!()
      |> Base.url_encode64(padding: false)

    %{
      "message" => %{
        "data" => encoded,
        "messageId" => "pubsub-message-1",
        "publishTime" => "2026-05-14T12:00:00.000Z"
      },
      "subscription" => "projects/project-1/subscriptions/gmail"
    }
  end
end
