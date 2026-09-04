defmodule Jido.Connect.MicrosoftSharepoint.CatalogPacksTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Catalog
  alias Jido.Connect.MicrosoftSharepoint

  test "metadata pack excludes content and mutation tools" do
    ids = search_ids(:microsoft_sharepoint_metadata)

    assert "microsoft.sharepoint.site.get" in ids
    assert "microsoft.sharepoint.list.columns.list" in ids
    assert "microsoft.sharepoint.libraries.list" in ids
    refute "microsoft.sharepoint.list.items.list" in ids
    refute "microsoft.sharepoint.library.item.download" in ids
    refute "microsoft.sharepoint.list.item.create" in ids
  end

  test "read and sync packs expose their intended read surfaces" do
    read_ids = search_ids(:microsoft_sharepoint_read)
    sync_ids = search_ids(:microsoft_sharepoint_sync)

    assert "microsoft.sharepoint.list.item.get" in read_ids
    assert "microsoft.sharepoint.library.item.download" in read_ids
    refute "microsoft.sharepoint.list.item.update" in read_ids

    assert "microsoft.sharepoint.list.items.delta" in sync_ids
    assert "microsoft.sharepoint.library.items.delta" in sync_ids
    refute "microsoft.sharepoint.library.item.download" in sync_ids
    refute "microsoft.sharepoint.library.item.upload" in sync_ids
  end

  test "write pack excludes delete and destructive pack includes it" do
    assert {:ok, upload} = describe_tool(:microsoft_sharepoint_write, "library.item.upload")
    assert upload.tool.id == "microsoft.sharepoint.library.item.upload"

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             describe_tool(:microsoft_sharepoint_write, "library.item.delete")

    assert {:ok, delete} =
             describe_tool(:microsoft_sharepoint_destructive, "library.item.delete")

    assert delete.tool.id == "microsoft.sharepoint.library.item.delete"
  end

  test "exports five stable pack delegates" do
    assert Enum.map(MicrosoftSharepoint.catalog_packs(), & &1.id) == [
             :microsoft_sharepoint_metadata,
             :microsoft_sharepoint_read,
             :microsoft_sharepoint_sync,
             :microsoft_sharepoint_write,
             :microsoft_sharepoint_destructive
           ]

    assert MicrosoftSharepoint.metadata_pack().id == :microsoft_sharepoint_metadata
    assert MicrosoftSharepoint.read_pack().id == :microsoft_sharepoint_read
    assert MicrosoftSharepoint.sync_pack().id == :microsoft_sharepoint_sync
    assert MicrosoftSharepoint.write_pack().id == :microsoft_sharepoint_write
    assert MicrosoftSharepoint.destructive_pack().id == :microsoft_sharepoint_destructive
  end

  defp search_ids(pack) do
    Catalog.search_tools("sharepoint",
      modules: [MicrosoftSharepoint],
      packs: MicrosoftSharepoint.catalog_packs(),
      pack: pack
    )
    |> Enum.map(& &1.tool.id)
  end

  defp describe_tool(pack, suffix) do
    Catalog.describe_tool("microsoft.sharepoint.#{suffix}",
      modules: [MicrosoftSharepoint],
      packs: MicrosoftSharepoint.catalog_packs(),
      pack: pack
    )
  end
end
