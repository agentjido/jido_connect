defmodule Jido.Connect.Gmail.PrivacyAuditTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Gmail
  alias Jido.Connect.Gmail.Normalizer
  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  test "classifies every Gmail action and trigger privacy boundary" do
    ConnectorContracts.assert_privacy_matrix(
      Gmail,
      [
        action("google.gmail.profile.get", :personal_data, :read, :none),
        action("google.gmail.labels.list", :personal_data, :read, :none),
        action("google.gmail.messages.list", :message_content, :read, :none,
          text_includes: ["metadata", "without fetching full message bodies"]
        ),
        action("google.gmail.message.get", :message_content, :read, :none,
          text_includes: ["message metadata", "no body data"]
        ),
        action("google.gmail.threads.list", :message_content, :read, :none,
          text_includes: ["metadata", "without fetching full message bodies"]
        ),
        action("google.gmail.thread.get", :message_content, :read, :none,
          text_includes: ["thread metadata", "no body data"]
        ),
        action("google.gmail.history.list", :message_content, :read, :none,
          text_includes: ["history records"]
        ),
        action("google.gmail.message.attachment.get", :message_content, :read, :none,
          text_includes: ["base64url-encoded", "attachment data"]
        ),
        action("google.gmail.message.send", :message_content, :external_write, :required_for_ai,
          text_includes: ["send", "body content"]
        ),
        action("google.gmail.draft.create", :message_content, :write, :required_for_ai,
          text_includes: ["draft", "body content"]
        ),
        action("google.gmail.draft.send", :message_content, :external_write, :required_for_ai),
        action("google.gmail.label.create", :personal_data, :write, :required_for_ai),
        action("google.gmail.message.labels.apply", :message_content, :write, :required_for_ai),
        action("google.gmail.watch.start", :personal_data, :write, :required_for_ai,
          text_includes: ["push notifications"]
        ),
        action("google.gmail.watch.stop", :personal_data, :write, :required_for_ai,
          text_includes: ["push notification delivery"]
        )
      ],
      [
        trigger("google.gmail.message.received", :message_content,
          text_includes: ["message", "received"]
        ),
        trigger("google.gmail.mailbox.changed", :personal_data,
          text_includes: ["cloud pub/sub", "history ids"]
        )
      ]
    )
  end

  test "normalizes Gmail message payloads without raw body leakage" do
    {:ok, message} =
      Normalizer.message(%{
        "id" => "msg123",
        "threadId" => "thread123",
        "raw" => "raw-secret",
        "payload" => %{
          "mimeType" => "multipart/alternative",
          "body" => %{"size" => 99, "data" => "body-secret"},
          "parts" => [
            %{
              "mimeType" => "text/plain",
              "body" => %{"size" => 12, "data" => "part-secret"}
            }
          ]
        }
      })

    refute inspect(message) =~ "raw-secret"
    refute inspect(message) =~ "body-secret"
    refute inspect(message) =~ "part-secret"
    assert message.payload_summary.body_size == 99
    assert [%{body_size: 12}] = message.payload_summary.parts
  end

  defp action(id, classification, risk, confirmation, opts \\ []) do
    %{
      id: id,
      classification: classification,
      risk: risk,
      confirmation: confirmation,
      text_includes: Keyword.get(opts, :text_includes, [])
    }
  end

  defp trigger(id, classification, opts) do
    %{
      id: id,
      classification: classification,
      text_includes: Keyword.get(opts, :text_includes, [])
    }
  end
end
