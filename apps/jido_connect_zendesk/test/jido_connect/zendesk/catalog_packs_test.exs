defmodule Jido.Connect.Zendesk.CatalogPacksTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Zendesk

  describe "pack delegates" do
    test "catalog_packs returns reader and editor packs" do
      packs = Zendesk.catalog_packs()
      pack_ids = Enum.map(packs, & &1.id)

      assert :zendesk_reader in pack_ids
      assert :zendesk_editor in pack_ids
    end

    test "all packs reference zendesk provider and correct package" do
      for pack <- Zendesk.catalog_packs() do
        assert pack.filters == %{provider: :zendesk}
        assert pack.metadata.package == :jido_connect_zendesk
      end
    end

    test "reader pack has read risk" do
      packs = Zendesk.catalog_packs()
      reader = Enum.find(packs, &(&1.id == :zendesk_reader))

      assert reader.metadata.risk == :read
      assert "zendesk.ticket.list" in reader.allowed_tools
      assert "zendesk.ticket.search" in reader.allowed_tools
      assert "zendesk.ticket.get" in reader.allowed_tools
      assert "zendesk.ticket.comment.list" in reader.allowed_tools
      assert "zendesk.user.list" in reader.allowed_tools
      assert "zendesk.organization.list" in reader.allowed_tools
    end

    test "editor pack has write risk" do
      packs = Zendesk.catalog_packs()
      editor = Enum.find(packs, &(&1.id == :zendesk_editor))

      assert editor.metadata.risk == :write
      # Editor includes all reader tools plus write tools
      assert "zendesk.ticket.list" in editor.allowed_tools
      assert "zendesk.ticket.get" in editor.allowed_tools
      assert "zendesk.ticket.create" in editor.allowed_tools
      assert "zendesk.ticket.update" in editor.allowed_tools
      assert "zendesk.ticket.comment.add" in editor.allowed_tools
    end

    test "reader pack excludes write tools" do
      packs = Zendesk.catalog_packs()
      reader = Enum.find(packs, &(&1.id == :zendesk_reader))

      refute "zendesk.ticket.create" in reader.allowed_tools
      refute "zendesk.ticket.update" in reader.allowed_tools
      refute "zendesk.ticket.comment.add" in reader.allowed_tools
    end
  end
end
