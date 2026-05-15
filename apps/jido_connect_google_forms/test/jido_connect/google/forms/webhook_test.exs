defmodule Jido.Connect.Google.Forms.WebhookTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Forms.Webhook

  describe "normalize_pubsub_push/1" do
    test "normalizes valid pubsub push payload" do
      data =
        %{
          "formId" => "1ABCdefGHI",
          "watchId" => "watch_abc123",
          "eventType" => "RESPONSE",
          "state" => "ACTIVE",
          "createTime" => "2026-05-14T12:00:00.000Z",
          "expireTime" => "2026-05-21T12:00:00.000Z"
        }
        |> Jason.encode!()
        |> Base.url_encode64(padding: false)

      payload = %{
        "message" => %{
          "data" => data,
          "messageId" => "msg_001",
          "publishTime" => "2026-05-14T12:00:01.000Z"
        },
        "subscription" => "projects/my-project/subscriptions/forms"
      }

      assert {:ok, signal} = Webhook.normalize_pubsub_push(payload)
      assert signal.form_id == "1ABCdefGHI"
      assert signal.watch_id == "watch_abc123"
      assert signal.event_type == "RESPONSE"
      assert signal.state == "ACTIVE"
      assert signal.create_time == "2026-05-14T12:00:00.000Z"
      assert signal.expire_time == "2026-05-21T12:00:00.000Z"
      assert signal.subscription == "projects/my-project/subscriptions/forms"
    end

    test "normalizes payload with id field as fallback for watch_id" do
      data =
        %{
          "formId" => "1ABCdefGHI",
          "id" => "watch_fallback"
        }
        |> Jason.encode!()
        |> Base.url_encode64(padding: false)

      payload = %{
        "message" => %{
          "data" => data
        }
      }

      assert {:ok, signal} = Webhook.normalize_pubsub_push(payload)
      assert signal.form_id == "1ABCdefGHI"
      assert signal.watch_id == "watch_fallback"
    end

    test "rejects payload without form_id" do
      data =
        %{"watchId" => "watch_abc123"}
        |> Jason.encode!()
        |> Base.url_encode64(padding: false)

      payload = %{
        "message" => %{
          "data" => data
        }
      }

      assert {:error, %Jido.Connect.Error.ProviderError{reason: :invalid_pubsub_data}} =
               Webhook.normalize_pubsub_push(payload)
    end

    test "rejects payload with empty form_id" do
      data =
        %{"formId" => ""}
        |> Jason.encode!()
        |> Base.url_encode64(padding: false)

      payload = %{
        "message" => %{
          "data" => data
        }
      }

      assert {:error, %Jido.Connect.Error.ProviderError{reason: :invalid_pubsub_data}} =
               Webhook.normalize_pubsub_push(payload)
    end

    test "rejects payload without message" do
      assert {:error, %Jido.Connect.Error.ProviderError{reason: :invalid_pubsub_payload}} =
               Webhook.normalize_pubsub_push(%{"foo" => "bar"})
    end

    test "rejects payload with invalid base64 data" do
      payload = %{
        "message" => %{
          "data" => "!!!invalid!!!"
        }
      }

      assert {:error, %Jido.Connect.Error.ProviderError{reason: :invalid_pubsub_data}} =
               Webhook.normalize_pubsub_push(payload)
    end

    test "rejects payload with non-object decoded data" do
      data =
        [1, 2, 3]
        |> Jason.encode!()
        |> Base.url_encode64(padding: false)

      payload = %{
        "message" => %{
          "data" => data
        }
      }

      assert {:error, %Jido.Connect.Error.ProviderError{reason: :invalid_pubsub_data}} =
               Webhook.normalize_pubsub_push(payload)
    end
  end
end
