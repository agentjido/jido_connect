defmodule Jido.Connect.Gmail.NormalizerTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Gmail.{
    Attachment,
    Draft,
    Label,
    Message,
    Normalizer,
    Privacy,
    Profile,
    Thread,
    Watch
  }

  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  test "normalizes profile payloads" do
    assert {:ok, %Profile{} = profile} =
             Normalizer.profile(%{
               "emailAddress" => "user@example.com",
               "messagesTotal" => 10,
               "threadsTotal" => 5,
               "historyId" => 123
             })

    assert profile.email_address == "user@example.com"
    assert profile.messages_total == 10
    assert profile.threads_total == 5
    assert profile.history_id == "123"
  end

  test "normalizes label payloads" do
    assert {:ok, %Label{} = label} =
             Normalizer.label(%{
               "id" => "Label_123",
               "name" => "Customers",
               "type" => "user",
               "messageListVisibility" => "show",
               "labelListVisibility" => "labelShow",
               "messagesTotal" => 12,
               "messagesUnread" => 2,
               "threadsTotal" => 8,
               "threadsUnread" => 1,
               "color" => %{"textColor" => "#000000", "backgroundColor" => "#ffffff"}
             })

    assert label.label_id == "Label_123"
    assert label.name == "Customers"
    assert label.messages_unread == 2
    assert label.color == %{"textColor" => "#000000", "backgroundColor" => "#ffffff"}
  end

  test "normalizes message payloads without raw body leakage" do
    assert {:ok, %Message{} = message} =
             Normalizer.message(message_payload())

    assert message.message_id == "msg123"
    assert message.thread_id == "thread123"
    assert message.label_ids == ["INBOX", "UNREAD"]
    assert message.history_id == "456"

    assert message.headers == [
             %{name: "From", value: "sender@example.com"},
             %{name: "Subject", value: "Quarterly budget"}
           ]

    assert message.payload_summary.mime_type == "multipart/alternative"
    assert [%{mime_type: "text/plain", body_size: 19}] = message.payload_summary.parts
    refute Map.has_key?(message.payload_summary, :body)
    refute inspect(message) =~ "body-bytes"
    refute inspect(message) =~ "raw-message"
  end

  test "normalizes thread payloads with sanitized messages" do
    assert {:ok, %Thread{} = thread} =
             Normalizer.thread(%{
               "id" => "thread123",
               "historyId" => "456",
               "messages" => [message_payload()]
             })

    assert thread.thread_id == "thread123"
    assert thread.snippet == "Budget update"
    assert [%Message{message_id: "msg123"}] = thread.messages
    refute inspect(thread) =~ "body-bytes"
  end

  test "returns errors instead of raising for malformed nested thread messages" do
    assert {:error, _error} =
             Normalizer.thread(%{
               "id" => "thread123",
               "messages" => [
                 %{"threadId" => "thread123"}
               ]
             })
  end

  test "ignores malformed payload parts collections" do
    assert {:ok, %Message{} = message} =
             Normalizer.message(%{
               "id" => "msg123",
               "payload" => %{
                 "mimeType" => "text/plain",
                 "parts" => nil
               }
             })

    assert message.payload_summary.parts == []
  end

  test "normalizes draft payloads with sanitized message" do
    assert {:ok, %Draft{} = draft} =
             Normalizer.draft(%{
               "id" => "draft123",
               "message" => message_payload()
             })

    assert draft.draft_id == "draft123"
    assert draft.message.message_id == "msg123"
    refute inspect(draft) =~ "body-bytes"
  end

  test "normalizes watch responses" do
    assert {:ok, %Watch{} = watch} =
             Normalizer.watch(%{
               "historyId" => 126,
               "expiration" => 1_710_000_000_000
             })

    assert watch.history_id == "126"
    assert watch.expiration == "1710000000000"
  end

  test "normalizes attachment payloads without decoding provider data" do
    assert {:ok, %Attachment{} = attachment} =
             Normalizer.attachment(%{
               "attachmentId" => "att123",
               "size" => "12",
               "data" => "Ym9keS1ieXRlcw"
             })

    assert attachment.attachment_id == "att123"
    assert attachment.size == 12
    assert attachment.data == "Ym9keS1ieXRlcw"
  end

  test "documents raw body keys and content fields" do
    assert Privacy.raw_body_key?("raw")
    assert Privacy.raw_body_key?(:data)
    assert :snippet in Privacy.message_content_fields()
    assert :headers in Privacy.message_content_fields()
  end

  test "normalizer public helpers reject malformed payloads safely" do
    assert {:error, :invalid_profile_payload} = Normalizer.profile(:bad)
    assert {:error, :invalid_label_payload} = Normalizer.label(:bad)
    assert {:error, :invalid_message_payload} = Normalizer.message(:bad)
    assert {:error, :invalid_thread_payload} = Normalizer.thread(:bad)
    assert {:error, :invalid_draft_payload} = Normalizer.draft(:bad)
    assert {:error, :invalid_watch_payload} = Normalizer.watch(:bad)
    assert {:error, :invalid_attachment_payload} = Normalizer.attachment(:bad)

    assert {:ok, %Draft{message: nil}} = Normalizer.draft(%{"id" => "draft123"})
    assert Normalizer.summarize_payload(:bad) == %{}
    assert Normalizer.normalize_headers(:bad) == []

    assert Normalizer.normalize_headers([
             %{"name" => "Subject", "value" => "Budget"},
             %{"name" => "Missing value"},
             :bad
           ]) == [%{name: "Subject", value: "Budget"}]

    assert Normalizer.reject_raw_body_keys(%{
             "raw" => "secret",
             :data => "secret",
             "safe" => true
           }) ==
             %{"safe" => true}
  end

  test "struct constructors expose schema defaults" do
    ConnectorContracts.assert_struct_defaults(Profile, %{email_address: "user@example.com"},
      metadata: %{}
    )

    assert {:error, _error} = Profile.new(%{})

    ConnectorContracts.assert_struct_defaults(Label, %{label_id: "INBOX", name: "INBOX"},
      color: %{},
      metadata: %{}
    )

    assert {:error, _error} = Label.new(%{label_id: "INBOX"})

    ConnectorContracts.assert_struct_defaults(Message, %{message_id: "msg123"},
      label_ids: [],
      headers: [],
      payload_summary: %{},
      metadata: %{}
    )

    assert {:error, _error} = Message.new(%{})

    ConnectorContracts.assert_struct_defaults(Thread, %{thread_id: "thread123"},
      messages: [],
      metadata: %{}
    )

    assert {:error, _error} = Thread.new(%{})

    ConnectorContracts.assert_struct_defaults(Draft, %{draft_id: "draft123"}, metadata: %{})
    assert {:error, _error} = Draft.new(%{})

    ConnectorContracts.assert_struct_defaults(Watch, %{history_id: "126"}, metadata: %{})
    assert {:error, _error} = Watch.new(%{})

    ConnectorContracts.assert_struct_defaults(Attachment, %{},
      size: 0,
      metadata: %{}
    )
  end

  defp message_payload do
    %{
      "id" => "msg123",
      "threadId" => "thread123",
      "labelIds" => ["INBOX", "UNREAD"],
      "snippet" => "Budget update",
      "historyId" => 456,
      "internalDate" => "1767225600000",
      "sizeEstimate" => "2048",
      "raw" => "raw-message",
      "payload" => %{
        "partId" => "",
        "mimeType" => "multipart/alternative",
        "headers" => [
          %{"name" => "From", "value" => "sender@example.com"},
          %{"name" => "Subject", "value" => "Quarterly budget"}
        ],
        "body" => %{"size" => 0, "data" => "body-bytes"},
        "parts" => [
          %{
            "partId" => "0",
            "mimeType" => "text/plain",
            "filename" => "",
            "body" => %{"size" => 19, "data" => "body-bytes"}
          }
        ]
      }
    }
  end
end
