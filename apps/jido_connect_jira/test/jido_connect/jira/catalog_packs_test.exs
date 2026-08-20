defmodule Jido.Connect.Jira.CatalogPacksTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Catalog
  alias Jido.Connect.Jira

  describe "reader pack" do
    test "exposes only read tools" do
      results =
        Catalog.search_tools("jira",
          modules: [Jira],
          packs: Jira.catalog_packs(),
          pack: :jira_reader
        )

      ids = Enum.map(results, & &1.tool.id)

      # Issue reads
      assert "jira.issue.get" in ids
      assert "jira.issue.search" in ids

      # Project reads
      assert "jira.project.list" in ids
      assert "jira.project.get" in ids

      # Metadata reads
      assert "jira.field_schema.list" in ids

      # Expanded reads
      assert "jira.board.list" in ids
      assert "jira.board.get" in ids
      assert "jira.filter.list" in ids
      assert "jira.filter.get" in ids
      assert "jira.filter.columns.get" in ids
      assert "jira.issue.transition.list" in ids

      # Privileged reads excluded
      refute "jira.plan.list" in ids
      refute "jira.plan.get" in ids

      # Write tools excluded
      refute "jira.issue.create" in ids
      refute "jira.issue.update" in ids
      refute "jira.issue.transition" in ids
      refute "jira.issue.assign" in ids
      refute "jira.issue.comment.create" in ids
      refute "jira.issue.delete" in ids
    end

    test "describe_tool accepts reader tools and rejects write tools" do
      assert {:ok, descriptor} =
               Catalog.describe_tool("jira.issue.get",
                 modules: [Jira],
                 packs: Jira.catalog_packs(),
                 pack: :jira_reader
               )

      assert descriptor.tool.id == "jira.issue.get"

      assert {:ok, descriptor} =
               Catalog.describe_tool("jira.project.list",
                 modules: [Jira],
                 packs: Jira.catalog_packs(),
                 pack: :jira_reader
               )

      assert descriptor.tool.id == "jira.project.list"

      assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
               Catalog.describe_tool("jira.issue.create",
                 modules: [Jira],
                 packs: Jira.catalog_packs(),
                 pack: :jira_reader
               )

      assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
               Catalog.describe_tool("jira.issue.comment.create",
                 modules: [Jira],
                 packs: Jira.catalog_packs(),
                 pack: :jira_reader
               )
    end
  end

  describe "editor pack" do
    test "exposes read and write tools" do
      results =
        Catalog.search_tools("jira",
          modules: [Jira],
          packs: Jira.catalog_packs(),
          pack: :jira_editor
        )

      ids = Enum.map(results, & &1.tool.id)

      # All read tools
      assert "jira.issue.get" in ids
      assert "jira.issue.search" in ids
      assert "jira.project.list" in ids
      assert "jira.project.get" in ids
      assert "jira.field_schema.list" in ids

      # Write tools included
      assert "jira.issue.create" in ids
      assert "jira.issue.update" in ids
      assert "jira.issue.transition" in ids
      assert "jira.issue.assign" in ids
      assert "jira.issue.comment.create" in ids
      assert "jira.board.create" in ids
      assert "jira.filter.create" in ids
      assert "jira.filter.update" in ids
      assert "jira.filter.columns.update" in ids
      assert "jira.filter.share.update" in ids

      refute "jira.issue.delete" in ids
      refute "jira.plan.create" in ids
    end

    test "describe_tool accepts write tools" do
      assert {:ok, descriptor} =
               Catalog.describe_tool("jira.issue.create",
                 modules: [Jira],
                 packs: Jira.catalog_packs(),
                 pack: :jira_editor
               )

      assert descriptor.tool.id == "jira.issue.create"

      assert {:ok, descriptor} =
               Catalog.describe_tool("jira.issue.update",
                 modules: [Jira],
                 packs: Jira.catalog_packs(),
                 pack: :jira_editor
               )

      assert descriptor.tool.id == "jira.issue.update"

      assert {:ok, descriptor} =
               Catalog.describe_tool("jira.issue.comment.create",
                 modules: [Jira],
                 packs: Jira.catalog_packs(),
                 pack: :jira_editor
               )

      assert descriptor.tool.id == "jira.issue.comment.create"
    end
  end

  describe "admin pack" do
    test "exposes non-destructive plan tools" do
      ids =
        Catalog.search_tools("jira",
          modules: [Jira],
          packs: Jira.catalog_packs(),
          pack: :jira_admin
        )
        |> Enum.map(& &1.tool.id)

      assert "jira.plan.list" in ids
      assert "jira.plan.get" in ids
      assert "jira.plan.create" in ids
      assert "jira.plan.update" in ids
      assert "jira.plan.duplicate" in ids
      refute "jira.plan.archive" in ids
      refute "jira.plan.trash" in ids
      refute "jira.issue.delete" in ids
    end
  end

  describe "destructive pack" do
    test "exposes only explicitly destructive Jira tools" do
      ids =
        Catalog.search_tools("jira",
          modules: [Jira],
          packs: Jira.catalog_packs(),
          pack: :jira_destructive
        )
        |> Enum.map(& &1.tool.id)

      assert MapSet.new(ids) ==
               MapSet.new([
                 "jira.issue.delete",
                 "jira.plan.archive",
                 "jira.plan.trash"
               ])
    end
  end

  describe "pack delegates" do
    test "catalog_packs returns reader, editor, admin, and destructive packs" do
      packs = Jira.catalog_packs()
      pack_ids = Enum.map(packs, & &1.id)

      assert :jira_reader in pack_ids
      assert :jira_editor in pack_ids
      assert :jira_admin in pack_ids
      assert :jira_destructive in pack_ids
    end

    test "all packs reference jira provider and correct package" do
      for pack <- Jira.catalog_packs() do
        assert pack.filters == %{provider: :jira}
        assert pack.metadata.package == :jido_connect_jira
      end
    end
  end
end
