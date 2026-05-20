defmodule Jido.Connect.Asana.CatalogPacksTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Asana

  describe "pack delegates" do
    test "catalog_packs returns reader and editor packs" do
      packs = Asana.catalog_packs()
      pack_ids = Enum.map(packs, & &1.id)

      assert :asana_reader in pack_ids
      assert :asana_editor in pack_ids
    end

    test "all packs reference asana provider and correct package" do
      for pack <- Asana.catalog_packs() do
        assert pack.filters == %{provider: :asana}
        assert pack.metadata.package == :jido_connect_asana
      end
    end

    test "reader pack has read risk and includes read tools" do
      packs = Asana.catalog_packs()
      reader = Enum.find(packs, &(&1.id == :asana_reader))

      assert reader.metadata.risk == :read
      assert "asana.workspace.list" in reader.allowed_tools
      assert "asana.project.list" in reader.allowed_tools
      assert "asana.task.list" in reader.allowed_tools
      assert "asana.task.get" in reader.allowed_tools
      assert "asana.task.search" in reader.allowed_tools
      assert "asana.story.list" in reader.allowed_tools
      assert "asana.user.get" in reader.allowed_tools
      assert "asana.user.list" in reader.allowed_tools
    end

    test "editor pack has write risk and includes reader tools" do
      packs = Asana.catalog_packs()
      editor = Enum.find(packs, &(&1.id == :asana_editor))

      assert editor.metadata.risk == :write
      assert "asana.workspace.list" in editor.allowed_tools
      assert "asana.task.get" in editor.allowed_tools
    end

    test "editor pack includes all reader tools" do
      packs = Asana.catalog_packs()
      reader = Enum.find(packs, &(&1.id == :asana_reader))
      editor = Enum.find(packs, &(&1.id == :asana_editor))

      for tool <- reader.allowed_tools do
        assert tool in editor.allowed_tools,
               "Expected reader tool #{tool} in editor allowed_tools"
      end
    end
  end
end
