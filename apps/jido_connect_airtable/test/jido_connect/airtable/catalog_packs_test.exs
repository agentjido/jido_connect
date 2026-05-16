defmodule Jido.Connect.Airtable.CatalogPacksTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Catalog
  alias Jido.Connect.Airtable

  describe "reader pack" do
    test "exposes only read tools" do
      results =
        Catalog.search_tools("airtable",
          modules: [Airtable],
          packs: Airtable.catalog_packs(),
          pack: :airtable_reader
        )

      ids = Enum.map(results, & &1.tool.id)

      # Base reads
      assert "airtable.bases.list" in ids
      assert "airtable.bases.get" in ids

      # Record reads
      assert "airtable.records.list" in ids
      assert "airtable.records.get" in ids

      # Write tools excluded
      refute "airtable.records.create" in ids
      refute "airtable.records.update" in ids
      refute "airtable.records.delete" in ids
    end

    test "describe_tool accepts reader tools and rejects write tools" do
      assert {:ok, descriptor} =
               Catalog.describe_tool("airtable.bases.list",
                 modules: [Airtable],
                 packs: Airtable.catalog_packs(),
                 pack: :airtable_reader
               )

      assert descriptor.tool.id == "airtable.bases.list"

      assert {:ok, descriptor} =
               Catalog.describe_tool("airtable.records.list",
                 modules: [Airtable],
                 packs: Airtable.catalog_packs(),
                 pack: :airtable_reader
               )

      assert descriptor.tool.id == "airtable.records.list"

      assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
               Catalog.describe_tool("airtable.records.create",
                 modules: [Airtable],
                 packs: Airtable.catalog_packs(),
                 pack: :airtable_reader
               )

      assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
               Catalog.describe_tool("airtable.records.delete",
                 modules: [Airtable],
                 packs: Airtable.catalog_packs(),
                 pack: :airtable_reader
               )
    end
  end

  describe "editor pack" do
    test "exposes read and record write tools" do
      results =
        Catalog.search_tools("airtable",
          modules: [Airtable],
          packs: Airtable.catalog_packs(),
          pack: :airtable_editor
        )

      ids = Enum.map(results, & &1.tool.id)

      # All read tools
      assert "airtable.bases.list" in ids
      assert "airtable.bases.get" in ids
      assert "airtable.records.list" in ids
      assert "airtable.records.get" in ids

      # Write tools included
      assert "airtable.records.create" in ids
      assert "airtable.records.update" in ids
      assert "airtable.records.delete" in ids
    end

    test "describe_tool accepts write tools" do
      assert {:ok, descriptor} =
               Catalog.describe_tool("airtable.records.create",
                 modules: [Airtable],
                 packs: Airtable.catalog_packs(),
                 pack: :airtable_editor
               )

      assert descriptor.tool.id == "airtable.records.create"

      assert {:ok, descriptor} =
               Catalog.describe_tool("airtable.records.update",
                 modules: [Airtable],
                 packs: Airtable.catalog_packs(),
                 pack: :airtable_editor
               )

      assert descriptor.tool.id == "airtable.records.update"

      assert {:ok, descriptor} =
               Catalog.describe_tool("airtable.records.delete",
                 modules: [Airtable],
                 packs: Airtable.catalog_packs(),
                 pack: :airtable_editor
               )

      assert descriptor.tool.id == "airtable.records.delete"
    end
  end

  describe "pack delegates" do
    test "catalog_packs returns reader and editor packs" do
      packs = Airtable.catalog_packs()
      pack_ids = Enum.map(packs, & &1.id)

      assert pack_ids == [:airtable_reader, :airtable_editor]
    end

    test "all packs reference airtable provider and correct package" do
      for pack <- Airtable.catalog_packs() do
        assert pack.filters == %{provider: :airtable}
        assert pack.metadata.package == :jido_connect_airtable
      end
    end
  end
end
