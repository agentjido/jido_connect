defmodule Jido.Connect.MicrosoftOnedrive.PrivacyAuditTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Jido.Connect.Microsoft.TestSupport.ConnectorContracts
  alias Jido.Connect.MicrosoftOnedrive
  alias Jido.Connect.MicrosoftOnedrive.Privacy

  test "classifies every Microsoft OneDrive action privacy boundary" do
    spec = MicrosoftOnedrive.integration()
    actions_by_id = Map.new(spec.actions, &{&1.id, &1})

    expected =
      MapSet.new([
        "microsoft.onedrive.items.list",
        "microsoft.onedrive.item.get",
        "microsoft.onedrive.drive.get",
        "microsoft.onedrive.item.create",
        "microsoft.onedrive.item.update",
        "microsoft.onedrive.item.upload",
        "microsoft.onedrive.item.delete"
      ])

    assert MapSet.new(Map.keys(actions_by_id)) == expected

    # ── Read actions ───────────────────────────────────────────────────
    items_list = actions_by_id["microsoft.onedrive.items.list"]
    assert items_list.data_classification == :personal_data
    assert items_list.risk == :read
    assert items_list.confirmation == :none

    item_get = actions_by_id["microsoft.onedrive.item.get"]
    assert item_get.data_classification == :personal_data
    assert item_get.risk == :read
    assert item_get.confirmation == :none

    drive_get = actions_by_id["microsoft.onedrive.drive.get"]
    assert drive_get.data_classification == :personal_data
    assert drive_get.risk == :read
    assert drive_get.confirmation == :none

    # ── Write / external_write actions ─────────────────────────────────
    item_create = actions_by_id["microsoft.onedrive.item.create"]
    assert item_create.data_classification == :personal_data
    assert item_create.risk == :external_write
    assert item_create.confirmation == :required_for_ai

    item_update = actions_by_id["microsoft.onedrive.item.update"]
    assert item_update.data_classification == :personal_data
    assert item_update.risk == :write
    assert item_update.confirmation == :required_for_ai

    item_upload = actions_by_id["microsoft.onedrive.item.upload"]
    assert item_upload.data_classification == :personal_data
    assert item_upload.risk == :external_write
    assert item_upload.confirmation == :required_for_ai

    # ── Destructive actions ────────────────────────────────────────────
    item_delete = actions_by_id["microsoft.onedrive.item.delete"]
    assert item_delete.data_classification == :personal_data
    assert item_delete.risk == :destructive
    assert item_delete.confirmation == :always
  end

  test "privacy module lists storage content and personal data fields" do
    content_fields = Privacy.storage_content_fields()
    assert :name in content_fields
    assert :size in content_fields
    assert :web_url in content_fields
    assert :created_by in content_fields
    assert :last_modified_by in content_fields

    personal_fields = Privacy.personal_data_fields()
    assert :display_name in personal_fields
    assert :email in personal_fields
    assert :name in personal_fields
    assert :web_url in personal_fields
    assert :created_by in personal_fields
    assert :last_modified_by in personal_fields
    assert :item_id in personal_fields
    assert :parent_reference in personal_fields
  end

  test "privacy module detects raw content keys" do
    assert Privacy.raw_content_key?("content")
    assert Privacy.raw_content_key?(:content)
    assert Privacy.raw_content_key?("@content.downloadUrl")
    assert Privacy.raw_content_key?(:"@content.downloadUrl")
    refute Privacy.raw_content_key?("name")
    refute Privacy.raw_content_key?("size")
    refute Privacy.raw_content_key?(:id)
  end

  test "every action has reviewed data classification, risk, and confirmation" do
    spec = MicrosoftOnedrive.integration()

    known_classifications = MapSet.new([:personal_data])
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
    ConnectorContracts.assert_microsoft_naming_and_catalog_conventions(MicrosoftOnedrive,
      id_prefix: "microsoft.onedrive.",
      pack_id_prefix: "microsoft_onedrive_",
      module_namespace: Jido.Connect.MicrosoftOnedrive
    )
  end
end
