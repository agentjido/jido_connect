defmodule Jido.Connect.MicrosoftOutlook.NormalizerTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.MicrosoftOutlook.{
    Attachment,
    Folder,
    Message,
    Normalizer,
    Recipient
  }

  # ── Fixture helpers ───────────────────────────────────────────────────

  defp fixture!(name) do
    __DIR__
    |> Path.join("../../fixtures/outlook/#{name}.json")
    |> Path.expand()
    |> File.read!()
    |> Jason.decode!()
  end

  defp folder_inbox, do: fixture!("folder_inbox")
  defp folders_list, do: fixture!("folders_list")
  defp messages_list, do: fixture!("messages_list")
  defp message_detail, do: fixture!("message_detail")
  defp attachment_file, do: fixture!("attachment_file")
  defp messages_empty, do: fixture!("messages_empty")

  # ── Folder ────────────────────────────────────────────────────────────

  describe "folder/1" do
    test "normalizes a Microsoft Graph mailFolder payload" do
      assert {:ok, %Folder{} = folder} = Normalizer.folder(folder_inbox())

      assert folder.folder_id == "AAMkAGI2TG93AAA="
      assert folder.display_name == "Inbox"
      assert folder.parent_folder_id == "AAMkAGI2AABhAAA="
      assert folder.child_folder_count == 2
      assert folder.unread_item_count == 5
      assert folder.total_item_count == 42
      assert folder.well_known_name == "inbox"
    end

    test "normalizes a folder without wellKnownName" do
      assert {:ok, %Folder{} = folder} =
               Normalizer.folder(%{
                 "id" => "AAMkCustom=",
                 "displayName" => "Custom Folder",
                 "totalItemCount" => 0
               })

      assert folder.display_name == "Custom Folder"
      assert folder.well_known_name == nil
      assert folder.total_item_count == 0
    end

    test "rejects malformed folder payloads" do
      assert {:error, :invalid_folder_payload} = Normalizer.folder(:bad)
      assert {:error, :invalid_folder_payload} = Normalizer.folder(nil)
    end
  end

  # ── Message ───────────────────────────────────────────────────────────

  describe "message/1" do
    test "normalizes a full message payload from fixture" do
      assert {:ok, %Message{} = msg} = Normalizer.message(message_detail())

      assert msg.message_id == "AAMkAGI2TG93AAAqBGHNAAA="
      assert msg.conversation_id =~ "AAQkAGI2"
      assert msg.subject == "Quarterly budget review"
      assert msg.body_preview =~ "quarterly budget"
      assert msg.importance == "normal"
      assert msg.is_read == false
      assert msg.is_draft == false
      assert msg.has_attachments == true
      assert msg.internet_message_id =~ "@contoso.com"
      assert msg.received_date_time == "2026-05-19T12:00:00Z"
      assert msg.sent_date_time == "2026-05-19T11:59:00Z"
    end

    test "normalizes sender and from recipients" do
      assert {:ok, %Message{} = msg} = Normalizer.message(message_detail())

      assert msg.sender == %{name: "Megan Bowen", address: "meganb@contoso.com"}
      assert msg.from == %{name: "Megan Bowen", address: "meganb@contoso.com"}
    end

    test "normalizes to, cc, and bcc recipient lists" do
      assert {:ok, %Message{} = msg} = Normalizer.message(message_detail())

      assert [%{name: "All Users", address: "allusers@contoso.com"}] = msg.to_recipients
      assert [%{name: "Brian Johnson", address: "brianj@contoso.com"}] = msg.cc_recipients
      assert msg.bcc_recipients == []
    end

    test "summarizes body without exposing raw content" do
      assert {:ok, %Message{} = msg} = Normalizer.message(message_detail())

      assert msg.body_summary.content_type == "html"
      assert is_integer(msg.body_summary.body_size)
      # Raw content key should not be present
      refute Map.has_key?(msg.body_summary, :content)
    end

    test "normalizes inline attachments metadata only" do
      assert {:ok, %Message{} = msg} = Normalizer.message(message_detail())

      assert length(msg.attachments) == 2

      [first, second] = msg.attachments

      assert first.attachment_id == "AAMkAGI2TG93AAAqBGHNAAAqBGHLAAA="
      assert first.name == "budget_q2_2026.xlsx"
      assert first.content_type =~ "spreadsheetml"
      assert first.size == 45678
      assert first.is_inline == false

      assert second.name == "logo.png"
      assert second.is_inline == true
      # No content bytes in metadata
      refute Map.has_key?(first, :content)
    end

    test "populates folders from parentFolderId" do
      assert {:ok, %Message{} = msg} = Normalizer.message(message_detail())

      assert msg.folders == ["AAMkAGI2TG93AAA="]
    end

    test "handles message with no recipients gracefully" do
      assert {:ok, %Message{} = msg} =
               Normalizer.message(%{
                 "id" => "msg-empty-rcpts",
                 "toRecipients" => nil,
                 "ccRecipients" => nil,
                 "bccRecipients" => nil,
                 "body" => nil,
                 "attachments" => nil
               })

      assert msg.to_recipients == []
      assert msg.cc_recipients == []
      assert msg.bcc_recipients == []
      assert msg.body_summary == %{}
      assert msg.attachments == []
      assert msg.folders == []
    end

    test "rejects malformed message payloads" do
      assert {:error, :invalid_message_payload} = Normalizer.message(:bad)
      assert {:error, :invalid_message_payload} = Normalizer.message("string")
    end
  end

  # ── Recipient ─────────────────────────────────────────────────────────

  describe "recipient/1" do
    test "normalizes a Microsoft Graph recipient object" do
      assert {:ok, %Recipient{} = recip} =
               Normalizer.recipient(%{
                 "emailAddress" => %{
                   "name" => "Megan Bowen",
                   "address" => "meganb@contoso.com"
                 }
               })

      assert recip.name == "Megan Bowen"
      assert recip.address == "meganb@contoso.com"
    end

    test "handles recipient with missing emailAddress" do
      assert {:ok, %Recipient{} = recip} = Normalizer.recipient(%{"emailAddress" => nil})

      assert recip.name == nil
      assert recip.address == nil
    end

    test "rejects malformed recipient payloads" do
      assert {:error, :invalid_recipient_payload} = Normalizer.recipient(:bad)
      assert {:error, :invalid_recipient_payload} = Normalizer.recipient(nil)
    end
  end

  # ── Attachment ────────────────────────────────────────────────────────

  describe "attachment/1" do
    test "normalizes a file attachment payload from fixture" do
      assert {:ok, %Attachment{} = att} = Normalizer.attachment(attachment_file())

      assert att.attachment_id == "AAMkAGI2TG93AAAqBGHNAAAqBGHLAAA="
      assert att.name == "budget_q2_2026.xlsx"

      assert att.content_type ==
               "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"

      assert att.size == 45678
      assert att.is_inline == false
    end

    test "defaults is_inline to false" do
      assert {:ok, %Attachment{} = att} =
               Normalizer.attachment(%{
                 "id" => "att-no-inline"
               })

      assert att.is_inline == false
    end

    test "rejects malformed attachment payloads" do
      assert {:error, :invalid_attachment_payload} = Normalizer.attachment(:bad)
      assert {:error, :invalid_attachment_payload} = Normalizer.attachment(nil)
    end
  end

  # ── Paging envelope ───────────────────────────────────────────────────

  describe "page/2" do
    test "extracts normalized folders from a Graph list envelope" do
      envelope = folders_list()

      assert {:ok, %{items: folders, next_link: next}} =
               Normalizer.page(envelope, &Normalizer.folder/1)

      assert length(folders) == 3
      assert [%Folder{display_name: "Inbox"} | _] = folders
      assert next =~ "$skip=10"
    end

    test "extracts normalized messages from a Graph list envelope" do
      envelope = messages_list()

      assert {:ok, %{items: messages, next_link: next}} =
               Normalizer.page(envelope, &Normalizer.message/1)

      assert length(messages) == 2
      assert [%Message{subject: "Quarterly budget review"} | _] = messages
      assert next =~ "$skip=25"
    end

    test "handles empty value array" do
      envelope = messages_empty()

      assert {:ok, %{items: [], next_link: nil}} =
               Normalizer.page(envelope, &Normalizer.message/1)
    end

    test "returns error for malformed envelope" do
      assert {:error, :invalid_page_envelope} = Normalizer.page(:bad, &Normalizer.folder/1)
      assert {:error, :invalid_page_envelope} = Normalizer.page(nil, &Normalizer.folder/1)
    end

    test "propagates normalizer errors" do
      envelope = %{
        "value" => [%{"displayName" => "Missing ID"}]
      }

      assert {:error, _reason} = Normalizer.page(envelope, &Normalizer.folder/1)
    end
  end

  # ── Batch helpers ─────────────────────────────────────────────────────

  describe "normalize_list/2" do
    test "normalizes multiple attachments" do
      payloads = [
        %{"id" => "att1", "name" => "file1.pdf", "size" => 100},
        %{"id" => "att2", "name" => "file2.pdf", "size" => 200}
      ]

      assert {:ok, [%Attachment{} = a1, %Attachment{} = a2]} =
               Normalizer.normalize_list(payloads, &Normalizer.attachment/1)

      assert a1.attachment_id == "att1"
      assert a2.attachment_id == "att2"
    end

    test "returns error for invalid list" do
      assert {:error, :invalid_list_payloads} =
               Normalizer.normalize_list(:bad, &Normalizer.attachment/1)
    end
  end

  # ── Struct contracts ──────────────────────────────────────────────────

  describe "struct contracts" do
    test "Folder struct exposes schema defaults and rejects invalid input" do
      folder = Folder.new!(%{folder_id: "id", display_name: "Inbox"})
      assert folder.metadata == %{}
      assert {:error, _error} = Folder.new(%{})
    end

    test "Message struct exposes schema defaults and rejects invalid input" do
      msg = Message.new!(%{message_id: "msg1"})
      assert msg.body_summary == %{}
      assert msg.to_recipients == []
      assert msg.cc_recipients == []
      assert msg.bcc_recipients == []
      assert msg.folders == []
      assert msg.attachments == []
      assert msg.metadata == %{}
      assert {:error, _error} = Message.new(%{})
    end

    test "Recipient struct accepts empty attributes" do
      assert {:ok, %Recipient{} = recip} = Recipient.new(%{})
      assert recip.metadata == %{}
    end

    test "Attachment struct exposes schema defaults and rejects invalid input" do
      att = Attachment.new!(%{attachment_id: "att1"})
      assert att.is_inline == false
      assert att.metadata == %{}
      assert {:error, _error} = Attachment.new(%{})
    end
  end
end
