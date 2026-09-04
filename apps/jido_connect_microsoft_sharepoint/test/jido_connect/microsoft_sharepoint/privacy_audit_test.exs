defmodule Jido.Connect.MicrosoftSharepoint.PrivacyAuditTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Microsoft.TestSupport.ConnectorContracts
  alias Jido.Connect.MicrosoftSharepoint
  alias Jido.Connect.MicrosoftSharepoint.Privacy

  test "classifies every SharePoint action" do
    actions = MicrosoftSharepoint.integration().actions

    metadata_actions =
      MapSet.new([
        "microsoft.sharepoint.site.resolve",
        "microsoft.sharepoint.site.get",
        "microsoft.sharepoint.sites.search",
        "microsoft.sharepoint.lists.list",
        "microsoft.sharepoint.list.get",
        "microsoft.sharepoint.list.columns.list"
      ])

    assert length(actions) == 22

    for action <- actions do
      expected_classification =
        if MapSet.member?(metadata_actions, action.id),
          do: :workspace_metadata,
          else: :workspace_content

      assert action.data_classification == expected_classification
      assert action.risk in [:read, :write, :external_write, :destructive]
      assert action.confirmation in [:none, :required_for_ai, :always]

      if action.risk in [:write, :external_write] do
        assert action.confirmation == :required_for_ai
      end

      if action.risk == :destructive do
        assert action.confirmation == :always
      end
    end
  end

  test "identifies content, personal data, and raw payload keys" do
    assert :fields in Privacy.workspace_content_fields()
    assert :name in Privacy.workspace_content_fields()
    assert :email in Privacy.personal_data_fields()
    assert :created_by in Privacy.personal_data_fields()

    assert Privacy.raw_content_key?("content")
    assert Privacy.raw_content_key?(:contentBytes)
    assert Privacy.raw_content_key?("@microsoft.graph.downloadUrl")
    refute Privacy.raw_content_key?(:name)
  end

  test "follows Microsoft naming and catalog conventions" do
    ConnectorContracts.assert_microsoft_naming_and_catalog_conventions(MicrosoftSharepoint,
      id_prefix: "microsoft.sharepoint.",
      pack_id_prefix: "microsoft_sharepoint_",
      module_namespace: Jido.Connect.MicrosoftSharepoint
    )
  end
end
