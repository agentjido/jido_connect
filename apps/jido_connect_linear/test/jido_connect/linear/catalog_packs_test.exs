defmodule Jido.Connect.Linear.CatalogPacksTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Catalog
  alias Jido.Connect.Linear

  describe "reader pack" do
    test "exposes only read tools" do
      results =
        Catalog.search_tools("linear",
          modules: [Linear],
          packs: Linear.catalog_packs(),
          pack: :linear_reader
        )

      ids = Enum.map(results, & &1.tool.id)

      # Issue reads
      assert "linear.issue.get" in ids
      assert "linear.issue.search" in ids
      assert "linear.issue.comments.list" in ids

      # Team reads
      assert "linear.team.list" in ids
      assert "linear.team.get" in ids

      # Write tools excluded
      refute "linear.issue.create" in ids
      refute "linear.issue.update" in ids
      refute "linear.issue.comment.create" in ids
    end

    test "describe_tool accepts reader tools and rejects write tools" do
      assert {:ok, descriptor} =
               Catalog.describe_tool("linear.issue.get",
                 modules: [Linear],
                 packs: Linear.catalog_packs(),
                 pack: :linear_reader
               )

      assert descriptor.tool.id == "linear.issue.get"

      assert {:ok, descriptor} =
               Catalog.describe_tool("linear.team.list",
                 modules: [Linear],
                 packs: Linear.catalog_packs(),
                 pack: :linear_reader
               )

      assert descriptor.tool.id == "linear.team.list"

      assert {:ok, descriptor} =
               Catalog.describe_tool("linear.issue.comments.list",
                 modules: [Linear],
                 packs: Linear.catalog_packs(),
                 pack: :linear_reader
               )

      assert descriptor.tool.id == "linear.issue.comments.list"

      assert {:ok, descriptor} =
               Catalog.describe_tool("linear.team.get",
                 modules: [Linear],
                 packs: Linear.catalog_packs(),
                 pack: :linear_reader
               )

      assert descriptor.tool.id == "linear.team.get"

      assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
               Catalog.describe_tool("linear.issue.create",
                 modules: [Linear],
                 packs: Linear.catalog_packs(),
                 pack: :linear_reader
               )

      assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
               Catalog.describe_tool("linear.issue.comment.create",
                 modules: [Linear],
                 packs: Linear.catalog_packs(),
                 pack: :linear_reader
               )
    end
  end

  describe "editor pack" do
    test "exposes read and write tools" do
      results =
        Catalog.search_tools("linear",
          modules: [Linear],
          packs: Linear.catalog_packs(),
          pack: :linear_editor
        )

      ids = Enum.map(results, & &1.tool.id)

      # All read tools
      assert "linear.issue.get" in ids
      assert "linear.issue.search" in ids
      assert "linear.issue.comments.list" in ids
      assert "linear.team.list" in ids
      assert "linear.team.get" in ids

      # Write tools included
      assert "linear.issue.create" in ids
      assert "linear.issue.update" in ids
      assert "linear.issue.comment.create" in ids
    end

    test "describe_tool accepts write tools" do
      assert {:ok, descriptor} =
               Catalog.describe_tool("linear.issue.create",
                 modules: [Linear],
                 packs: Linear.catalog_packs(),
                 pack: :linear_editor
               )

      assert descriptor.tool.id == "linear.issue.create"

      assert {:ok, descriptor} =
               Catalog.describe_tool("linear.issue.update",
                 modules: [Linear],
                 packs: Linear.catalog_packs(),
                 pack: :linear_editor
               )

      assert descriptor.tool.id == "linear.issue.update"

      assert {:ok, descriptor} =
               Catalog.describe_tool("linear.issue.comment.create",
                 modules: [Linear],
                 packs: Linear.catalog_packs(),
                 pack: :linear_editor
               )

      assert descriptor.tool.id == "linear.issue.comment.create"
    end
  end

  describe "pack delegates" do
    test "catalog_packs returns reader and editor packs" do
      packs = Linear.catalog_packs()
      pack_ids = Enum.map(packs, & &1.id)

      assert :linear_reader in pack_ids
      assert :linear_editor in pack_ids
    end

    test "all packs reference linear provider and correct package" do
      for pack <- Linear.catalog_packs() do
        assert pack.filters == %{provider: :linear}
        assert pack.metadata.package == :jido_connect_linear
      end
    end
  end
end
