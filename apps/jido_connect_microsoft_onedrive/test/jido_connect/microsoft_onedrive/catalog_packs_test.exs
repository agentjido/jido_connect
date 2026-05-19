defmodule Jido.Connect.MicrosoftOnedrive.CatalogPacksTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Catalog
  alias Jido.Connect.MicrosoftOnedrive

  test "metadata pack exposes only read tools" do
    results =
      Catalog.search_tools("onedrive",
        modules: [MicrosoftOnedrive],
        packs: MicrosoftOnedrive.catalog_packs(),
        pack: :microsoft_onedrive_metadata
      )

    ids = Enum.map(results, & &1.tool.id)

    assert "microsoft.onedrive.items.list" in ids
    assert "microsoft.onedrive.drive.get" in ids
    assert "microsoft.onedrive.drives.list" in ids
    assert "microsoft.onedrive.items.search" in ids
    assert "microsoft.onedrive.items.delta" in ids
    refute "microsoft.onedrive.item.get" in ids
    refute "microsoft.onedrive.item.download" in ids
    refute "microsoft.onedrive.item.create" in ids
    refute "microsoft.onedrive.item.update" in ids
    refute "microsoft.onedrive.item.upload" in ids
    refute "microsoft.onedrive.item.delete" in ids
    refute "microsoft.onedrive.item.create_link" in ids
    refute "microsoft.onedrive.item.permissions.list" in ids
    refute "microsoft.onedrive.item.permission.get" in ids
    refute "microsoft.onedrive.item.permission.create" in ids
    refute "microsoft.onedrive.item.permission.delete" in ids

    assert {:ok, descriptor} =
             Catalog.describe_tool("microsoft.onedrive.items.list",
               modules: [MicrosoftOnedrive],
               packs: MicrosoftOnedrive.catalog_packs(),
               pack: :microsoft_onedrive_metadata
             )

    assert descriptor.tool.id == "microsoft.onedrive.items.list"

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.describe_tool("microsoft.onedrive.item.create",
               modules: [MicrosoftOnedrive],
               packs: MicrosoftOnedrive.catalog_packs(),
               pack: :microsoft_onedrive_metadata
             )
  end

  test "triage pack allows read and detail tools and rejects write and delete" do
    assert {:ok, descriptor} =
             Catalog.describe_tool("microsoft.onedrive.item.get",
               modules: [MicrosoftOnedrive],
               packs: MicrosoftOnedrive.catalog_packs(),
               pack: :microsoft_onedrive_triage
             )

    assert descriptor.tool.id == "microsoft.onedrive.item.get"

    assert {:ok, drive_descriptor} =
             Catalog.describe_tool("microsoft.onedrive.drive.get",
               modules: [MicrosoftOnedrive],
               packs: MicrosoftOnedrive.catalog_packs(),
               pack: :microsoft_onedrive_triage
             )

    assert drive_descriptor.tool.id == "microsoft.onedrive.drive.get"

    assert {:ok, download_descriptor} =
             Catalog.describe_tool("microsoft.onedrive.item.download",
               modules: [MicrosoftOnedrive],
               packs: MicrosoftOnedrive.catalog_packs(),
               pack: :microsoft_onedrive_triage
             )

    assert download_descriptor.tool.id == "microsoft.onedrive.item.download"

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.describe_tool("microsoft.onedrive.item.create",
               modules: [MicrosoftOnedrive],
               packs: MicrosoftOnedrive.catalog_packs(),
               pack: :microsoft_onedrive_triage
             )

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.describe_tool("microsoft.onedrive.item.delete",
               modules: [MicrosoftOnedrive],
               packs: MicrosoftOnedrive.catalog_packs(),
               pack: :microsoft_onedrive_triage
             )
  end

  test "write pack allows create, update, and upload tools and rejects destructive" do
    assert {:ok, descriptor} =
             Catalog.describe_tool("microsoft.onedrive.item.create",
               modules: [MicrosoftOnedrive],
               packs: MicrosoftOnedrive.catalog_packs(),
               pack: :microsoft_onedrive_write
             )

    assert descriptor.tool.id == "microsoft.onedrive.item.create"

    assert {:ok, update_descriptor} =
             Catalog.describe_tool("microsoft.onedrive.item.update",
               modules: [MicrosoftOnedrive],
               packs: MicrosoftOnedrive.catalog_packs(),
               pack: :microsoft_onedrive_write
             )

    assert update_descriptor.tool.id == "microsoft.onedrive.item.update"

    assert {:ok, upload_descriptor} =
             Catalog.describe_tool("microsoft.onedrive.item.upload",
               modules: [MicrosoftOnedrive],
               packs: MicrosoftOnedrive.catalog_packs(),
               pack: :microsoft_onedrive_write
             )

    assert upload_descriptor.tool.id == "microsoft.onedrive.item.upload"

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.describe_tool("microsoft.onedrive.item.delete",
               modules: [MicrosoftOnedrive],
               packs: MicrosoftOnedrive.catalog_packs(),
               pack: :microsoft_onedrive_write
             )
  end

  test "destructive pack exposes delete tool" do
    assert {:ok, descriptor} =
             Catalog.describe_tool("microsoft.onedrive.item.delete",
               modules: [MicrosoftOnedrive],
               packs: MicrosoftOnedrive.catalog_packs(),
               pack: :microsoft_onedrive_destructive
             )

    assert descriptor.tool.id == "microsoft.onedrive.item.delete"
  end

  test "sharing pack exposes sharing link, permission listing, inspection, and invitation" do
    assert {:ok, link_descriptor} =
             Catalog.describe_tool("microsoft.onedrive.item.create_link",
               modules: [MicrosoftOnedrive],
               packs: MicrosoftOnedrive.catalog_packs(),
               pack: :microsoft_onedrive_sharing
             )

    assert link_descriptor.tool.id == "microsoft.onedrive.item.create_link"

    assert {:ok, list_descriptor} =
             Catalog.describe_tool("microsoft.onedrive.item.permissions.list",
               modules: [MicrosoftOnedrive],
               packs: MicrosoftOnedrive.catalog_packs(),
               pack: :microsoft_onedrive_sharing
             )

    assert list_descriptor.tool.id == "microsoft.onedrive.item.permissions.list"

    assert {:ok, get_descriptor} =
             Catalog.describe_tool("microsoft.onedrive.item.permission.get",
               modules: [MicrosoftOnedrive],
               packs: MicrosoftOnedrive.catalog_packs(),
               pack: :microsoft_onedrive_sharing
             )

    assert get_descriptor.tool.id == "microsoft.onedrive.item.permission.get"

    assert {:ok, create_descriptor} =
             Catalog.describe_tool("microsoft.onedrive.item.permission.create",
               modules: [MicrosoftOnedrive],
               packs: MicrosoftOnedrive.catalog_packs(),
               pack: :microsoft_onedrive_sharing
             )

    assert create_descriptor.tool.id == "microsoft.onedrive.item.permission.create"

    # Sharing pack excludes permission deletion
    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.describe_tool("microsoft.onedrive.item.permission.delete",
               modules: [MicrosoftOnedrive],
               packs: MicrosoftOnedrive.catalog_packs(),
               pack: :microsoft_onedrive_sharing
             )
  end

  test "admin pack exposes permission deletion" do
    assert {:ok, descriptor} =
             Catalog.describe_tool("microsoft.onedrive.item.permission.delete",
               modules: [MicrosoftOnedrive],
               packs: MicrosoftOnedrive.catalog_packs(),
               pack: :microsoft_onedrive_admin
             )

    assert descriptor.tool.id == "microsoft.onedrive.item.permission.delete"

    # Admin pack also includes sharing tools
    assert {:ok, link_descriptor} =
             Catalog.describe_tool("microsoft.onedrive.item.create_link",
               modules: [MicrosoftOnedrive],
               packs: MicrosoftOnedrive.catalog_packs(),
               pack: :microsoft_onedrive_admin
             )

    assert link_descriptor.tool.id == "microsoft.onedrive.item.create_link"
  end
end
