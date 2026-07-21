defmodule Jido.Connect.Zendesk.Handlers.Triggers.CommentChangedWebhookTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Zendesk.Handlers.Triggers.CommentChangedWebhook

  describe "normalize_signal/1" do
    test "delegates to Webhook.normalize_event for comment created" do
      delivery = %{
        "type" => "Comment Created",
        "id" => "wh-invocation-003",
        "account_id" => "example",
        "ticket" => %{
          "id" => 12345,
          "subject" => "Cannot reset password"
        },
        "current" => %{
          "id" => 50001,
          "body" => "Please check your spam folder.",
          "html_body" => "<p>Please check your spam folder.</p>",
          "public" => true,
          "author_id" => 9001
        },
        "timestamp" => "2026-03-15T11:00:00Z"
      }

      assert {:ok, signal} = CommentChangedWebhook.normalize_signal(delivery)
      assert signal.event_type == "Comment Created"
      assert signal.change_type == "created"
      assert signal.comment_id == 50001
      assert signal.comment_body == "Please check your spam folder."
      assert signal.comment_public == true
      assert signal.comment_author_id == 9001
      assert signal.ticket_id == 12345
      assert signal.ticket_subject == "Cannot reset password"
    end

    test "returns error when comment data is missing" do
      delivery = %{
        "type" => "Comment Created",
        "ticket" => %{"id" => 1},
        "current" => nil
      }

      assert {:error, error} = CommentChangedWebhook.normalize_signal(delivery)
      assert error.reason == :invalid_webhook_event
    end

    test "returns error when ticket context is missing" do
      delivery = %{
        "type" => "Comment Created",
        "current" => %{"id" => 50001, "body" => "hello"},
        "ticket" => nil
      }

      assert {:error, error} = CommentChangedWebhook.normalize_signal(delivery)
      assert error.reason == :invalid_webhook_event
    end

    test "returns error for invalid payload" do
      assert {:error, error} = CommentChangedWebhook.normalize_signal("not a map")
      assert error.reason == :invalid_webhook_event
    end
  end
end
