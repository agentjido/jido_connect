defmodule Jido.Connect.MicrosoftOutlook.PrivacyAuditTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Jido.Connect.Microsoft.TestSupport.ConnectorContracts
  alias Jido.Connect.MicrosoftOutlook
  alias Jido.Connect.MicrosoftOutlook.Normalizer

  test "classifies every Outlook Mail action privacy boundary" do
    spec = MicrosoftOutlook.integration()
    actions_by_id = Map.new(spec.actions, &{&1.id, &1})

    expected =
      MapSet.new([
        "microsoft.outlook.profile.get",
        "microsoft.outlook.messages.list",
        "microsoft.outlook.message.get",
        "microsoft.outlook.folders.list",
        "microsoft.outlook.folder.get",
        "microsoft.outlook.message.send",
        "microsoft.outlook.draft.create",
        "microsoft.outlook.draft.update",
        "microsoft.outlook.draft.send",
        "microsoft.outlook.message.reply",
        "microsoft.outlook.message.reply_all",
        "microsoft.outlook.message.move",
        "microsoft.outlook.message.delete",
        "microsoft.outlook.draft.delete"
      ])

    assert MapSet.new(Map.keys(actions_by_id)) == expected

    # ── Read actions ───────────────────────────────────────────────────
    profile = actions_by_id["microsoft.outlook.profile.get"]
    assert profile.data_classification == :personal_data
    assert profile.risk == :read
    assert profile.confirmation == :none

    messages_list = actions_by_id["microsoft.outlook.messages.list"]
    assert messages_list.data_classification == :message_content
    assert messages_list.risk == :read
    assert messages_list.confirmation == :none

    message_get = actions_by_id["microsoft.outlook.message.get"]
    assert message_get.data_classification == :message_content
    assert message_get.risk == :read
    assert message_get.confirmation == :none

    folders_list = actions_by_id["microsoft.outlook.folders.list"]
    assert folders_list.data_classification == :personal_data
    assert folders_list.risk == :read
    assert folders_list.confirmation == :none

    folder_get = actions_by_id["microsoft.outlook.folder.get"]
    assert folder_get.data_classification == :personal_data
    assert folder_get.risk == :read
    assert folder_get.confirmation == :none

    # ── Write / external_write actions ─────────────────────────────────
    message_send = actions_by_id["microsoft.outlook.message.send"]
    assert message_send.data_classification == :message_content
    assert message_send.risk == :external_write
    assert message_send.confirmation == :required_for_ai

    draft_create = actions_by_id["microsoft.outlook.draft.create"]
    assert draft_create.data_classification == :message_content
    assert draft_create.risk == :write
    assert draft_create.confirmation == :required_for_ai

    draft_update = actions_by_id["microsoft.outlook.draft.update"]
    assert draft_update.data_classification == :message_content
    assert draft_update.risk == :write
    assert draft_update.confirmation == :required_for_ai

    draft_send = actions_by_id["microsoft.outlook.draft.send"]
    assert draft_send.data_classification == :message_content
    assert draft_send.risk == :external_write
    assert draft_send.confirmation == :required_for_ai

    reply = actions_by_id["microsoft.outlook.message.reply"]
    assert reply.data_classification == :message_content
    assert reply.risk == :external_write
    assert reply.confirmation == :required_for_ai

    reply_all = actions_by_id["microsoft.outlook.message.reply_all"]
    assert reply_all.data_classification == :message_content
    assert reply_all.risk == :external_write
    assert reply_all.confirmation == :required_for_ai

    move = actions_by_id["microsoft.outlook.message.move"]
    assert move.data_classification == :message_content
    assert move.risk == :write
    assert move.confirmation == :required_for_ai

    # ── Destructive actions ────────────────────────────────────────────
    message_delete = actions_by_id["microsoft.outlook.message.delete"]
    assert message_delete.data_classification == :message_content
    assert message_delete.risk == :destructive
    assert message_delete.confirmation == :always

    draft_delete = actions_by_id["microsoft.outlook.draft.delete"]
    assert draft_delete.data_classification == :message_content
    assert draft_delete.risk == :destructive
    assert draft_delete.confirmation == :always
  end

  test "normalizes Outlook message payloads without raw body leakage" do
    {:ok, message} =
      Normalizer.message(%{
        "id" => "msg123",
        "body" => %{
          "contentType" => "html",
          "content" => "<html><body>Secret body content</body></html>"
        },
        "attachments" => [
          %{
            "id" => "att-secret",
            "name" => "file.pdf",
            "contentType" => "application/pdf",
            "size" => 9999,
            "isInline" => false,
            "contentBytes" => "base64-secret-bytes"
          }
        ]
      })

    # Body content must not leak
    refute inspect(message) =~ "Secret body content"
    assert message.body_summary.content_type == "html"
    assert is_integer(message.body_summary.body_size)
    refute Map.has_key?(message.body_summary, :content)

    # Attachment contentBytes must not leak
    refute inspect(message) =~ "base64-secret-bytes"
    assert length(message.attachments) == 1
    refute Map.has_key?(hd(message.attachments), :contentBytes)
  end

  test "normalizes Outlook profile without exposing token-sensitive fields" do
    {:ok, message} =
      Normalizer.message(%{
        "id" => "msg456",
        "sender" => %{
          "emailAddress" => %{
            "name" => "Test User",
            "address" => "test@example.com"
          }
        },
        "toRecipients" => [
          %{
            "emailAddress" => %{
              "name" => "Recipient",
              "address" => "recipient@example.com"
            }
          }
        ]
      })

    # Sender and recipients are present as metadata only
    assert message.sender.name == "Test User"
    assert message.sender.address == "test@example.com"
    assert [%{name: "Recipient", address: "recipient@example.com"}] = message.to_recipients
  end

  test "privacy module lists message content and personal data fields" do
    alias Jido.Connect.MicrosoftOutlook.Privacy

    content_fields = Privacy.message_content_fields()
    assert :subject in content_fields
    assert :body_preview in content_fields
    assert :sender in content_fields
    assert :to_recipients in content_fields
    assert :cc_recipients in content_fields
    assert :bcc_recipients in content_fields

    personal_fields = Privacy.personal_data_fields()
    assert :display_name in personal_fields
    assert :address in personal_fields
    assert :email in personal_fields
  end

  test "privacy module detects raw body keys" do
    alias Jido.Connect.MicrosoftOutlook.Privacy

    assert Privacy.raw_body_key?("content")
    assert Privacy.raw_body_key?(:content)
    assert Privacy.raw_body_key?("contentBytes")
    assert Privacy.raw_body_key?(:contentBytes)
    refute Privacy.raw_body_key?("content_type")
    refute Privacy.raw_body_key?("body_size")
    refute Privacy.raw_body_key?(:id)
  end

  test "every action has reviewed data classification, risk, and confirmation" do
    spec = MicrosoftOutlook.integration()

    known_classifications = MapSet.new([:personal_data, :message_content])
    known_risks = MapSet.new([:read, :write, :external_write, :destructive])
    known_confirmations = MapSet.new([:none, :required_for_ai, :always])

    for action <- spec.actions do
      assert MapSet.member?(known_classifications, action.data_classification),
             "#{action.id} has unreviewed data_classification: #{inspect(action.data_classification)}"

      assert MapSet.member?(known_risks, action.risk),
             "#{action.id} has unreviewed risk: #{inspect(action.risk)}"

      assert MapSet.member?(known_confirmations, action.confirmation),
             "#{action.id} has unreviewed confirmation: #{inspect(action.confirmation)}"

      if action.risk == :external_write do
        refute action.confirmation == :none,
               "#{action.id} is external_write but has no confirmation requirement"
      end

      if action.risk == :destructive do
        assert action.confirmation == :always,
               "#{action.id} is destructive but confirmation is not :always"
      end
    end
  end

  test "naming and catalog conventions cover privacy metadata" do
    ConnectorContracts.assert_microsoft_naming_and_catalog_conventions(MicrosoftOutlook,
      id_prefix: "microsoft.outlook.",
      pack_id_prefix: "microsoft_outlook_",
      module_namespace: Jido.Connect.MicrosoftOutlook
    )
  end
end
