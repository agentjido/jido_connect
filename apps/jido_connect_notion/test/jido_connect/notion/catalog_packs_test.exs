defmodule Jido.Connect.Notion.CatalogPacksTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Notion

  describe "pack delegates" do
    test "catalog_packs returns reader and editor packs" do
      packs = Notion.catalog_packs()
      pack_ids = Enum.map(packs, & &1.id)

      assert :notion_reader in pack_ids
      assert :notion_editor in pack_ids
    end

    test "all packs reference notion provider and correct package" do
      for pack <- Notion.catalog_packs() do
        assert pack.filters == %{provider: :notion}
        assert pack.metadata.package == :jido_connect_notion
      end
    end

    test "reader pack has read risk and read tools" do
      packs = Notion.catalog_packs()
      reader = Enum.find(packs, &(&1.id == :notion_reader))

      assert reader.metadata.risk == :read

      assert reader.allowed_tools == [
               "notion.search",
               "notion.page.get",
               "notion.database.get",
               "notion.database.query",
               "notion.block.get",
               "notion.block.list_children",
               "notion.comment.list"
             ]
    end

    test "editor pack has write risk and includes read tools" do
      packs = Notion.catalog_packs()
      editor = Enum.find(packs, &(&1.id == :notion_editor))

      assert editor.metadata.risk == :write

      assert "notion.search" in editor.allowed_tools
      assert "notion.page.get" in editor.allowed_tools
      assert "notion.comment.list" in editor.allowed_tools
    end

    test "editor pack includes write tools" do
      packs = Notion.catalog_packs()
      editor = Enum.find(packs, &(&1.id == :notion_editor))

      write_tools = [
        "notion.page.create",
        "notion.page.update",
        "notion.block.append_children",
        "notion.block.update",
        "notion.block.archive",
        "notion.comment.create"
      ]

      for tool <- write_tools do
        assert tool in editor.allowed_tools, "Expected #{tool} in editor allowed_tools"
      end
    end

    test "editor pack includes all reader tools" do
      packs = Notion.catalog_packs()
      reader = Enum.find(packs, &(&1.id == :notion_reader))
      editor = Enum.find(packs, &(&1.id == :notion_editor))

      for tool <- reader.allowed_tools do
        assert tool in editor.allowed_tools,
               "Expected reader tool #{tool} in editor allowed_tools"
      end
    end
  end
end
