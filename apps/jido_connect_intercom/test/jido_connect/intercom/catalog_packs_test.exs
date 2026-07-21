defmodule Jido.Connect.Intercom.CatalogPacksTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Intercom

  describe "pack delegates" do
    test "catalog_packs returns reader and editor packs" do
      packs = Intercom.catalog_packs()
      pack_ids = Enum.map(packs, & &1.id)

      assert :intercom_reader in pack_ids
      assert :intercom_editor in pack_ids
    end

    test "all packs reference intercom provider and correct package" do
      for pack <- Intercom.catalog_packs() do
        assert pack.filters == %{provider: :intercom}
        assert pack.metadata.package == :jido_connect_intercom
      end
    end

    test "reader pack has read risk and read tool IDs" do
      packs = Intercom.catalog_packs()
      reader = Enum.find(packs, &(&1.id == :intercom_reader))

      assert reader.metadata.risk == :read
      assert "intercom.contact.list" in reader.allowed_tools
      assert "intercom.contact.search" in reader.allowed_tools
      assert "intercom.contact.get" in reader.allowed_tools
      assert "intercom.conversation.list" in reader.allowed_tools
      assert "intercom.conversation.search" in reader.allowed_tools
      assert "intercom.conversation.get" in reader.allowed_tools
      assert "intercom.admin.list" in reader.allowed_tools
      assert "intercom.team.list" in reader.allowed_tools
      assert length(reader.allowed_tools) == 8
    end

    test "editor pack has write risk and includes read + write tools" do
      packs = Intercom.catalog_packs()
      editor = Enum.find(packs, &(&1.id == :intercom_editor))

      assert editor.metadata.risk == :write

      # Editor pack includes all 8 read tools + 7 write tools
      assert length(editor.allowed_tools) == 15

      assert "intercom.contact.create" in editor.allowed_tools
      assert "intercom.contact.update" in editor.allowed_tools
      assert "intercom.conversation.reply" in editor.allowed_tools
      assert "intercom.conversation.add_note" in editor.allowed_tools
      assert "intercom.conversation.assign" in editor.allowed_tools
      assert "intercom.contact.tag" in editor.allowed_tools
      assert "intercom.contact.untag" in editor.allowed_tools
    end
  end
end
