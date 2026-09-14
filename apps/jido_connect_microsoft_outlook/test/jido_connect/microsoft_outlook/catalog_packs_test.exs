defmodule Jido.Connect.MicrosoftOutlook.CatalogPacksTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Catalog
  alias Jido.Connect.MicrosoftOutlook

  test "metadata pack exposes only read tools" do
    results =
      Catalog.search_tools("outlook",
        modules: [MicrosoftOutlook],
        packs: MicrosoftOutlook.catalog_packs(),
        pack: :microsoft_outlook_metadata
      )

    ids = Enum.map(results, & &1.tool.id)

    assert "microsoft.outlook.profile.get" in ids
    assert "microsoft.outlook.messages.list" in ids
    assert "microsoft.outlook.folders.list" in ids
    refute "microsoft.outlook.message.send" in ids
    refute "microsoft.outlook.draft.create" in ids
    refute "microsoft.outlook.message.delete" in ids
    refute "microsoft.outlook.message.move" in ids

    assert {:ok, descriptor} =
             Catalog.describe_tool("microsoft.outlook.profile.get",
               modules: [MicrosoftOutlook],
               packs: MicrosoftOutlook.catalog_packs(),
               pack: :microsoft_outlook_metadata
             )

    assert descriptor.tool.id == "microsoft.outlook.profile.get"

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.describe_tool("microsoft.outlook.message.send",
               modules: [MicrosoftOutlook],
               packs: MicrosoftOutlook.catalog_packs(),
               pack: :microsoft_outlook_metadata
             )
  end

  test "triage pack allows reads and rejects send" do
    assert {:ok, descriptor} =
             Catalog.describe_tool("microsoft.outlook.message.get",
               modules: [MicrosoftOutlook],
               packs: MicrosoftOutlook.catalog_packs(),
               pack: :microsoft_outlook_triage
             )

    assert descriptor.tool.id == "microsoft.outlook.message.get"

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.describe_tool("microsoft.outlook.message.send",
               modules: [MicrosoftOutlook],
               packs: MicrosoftOutlook.catalog_packs(),
               pack: :microsoft_outlook_triage
             )
  end

  test "send pack allows send and draft tools" do
    assert {:ok, descriptor} =
             Catalog.describe_tool("microsoft.outlook.message.send",
               modules: [MicrosoftOutlook],
               packs: MicrosoftOutlook.catalog_packs(),
               pack: :microsoft_outlook_send
             )

    assert descriptor.tool.id == "microsoft.outlook.message.send"

    assert {:ok, draft_descriptor} =
             Catalog.describe_tool("microsoft.outlook.draft.create",
               modules: [MicrosoftOutlook],
               packs: MicrosoftOutlook.catalog_packs(),
               pack: :microsoft_outlook_send
             )

    assert draft_descriptor.tool.id == "microsoft.outlook.draft.create"
  end

  test "no pack offers unimplemented move or delete operations" do
    blocked = [
      "microsoft.outlook.message.move",
      "microsoft.outlook.message.delete",
      "microsoft.outlook.draft.delete"
    ]

    assert Enum.map(MicrosoftOutlook.catalog_packs(), & &1.id) == [
             :microsoft_outlook_metadata,
             :microsoft_outlook_triage,
             :microsoft_outlook_send
           ]

    for pack <- MicrosoftOutlook.catalog_packs(), id <- blocked do
      refute id in pack.allowed_tools
    end
  end
end
