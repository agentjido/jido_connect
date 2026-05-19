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
      assert reader.allowed_tools == []
    end

    test "editor pack has write risk" do
      packs = Zendesk.catalog_packs()
      editor = Enum.find(packs, &(&1.id == :zendesk_editor))

      assert editor.metadata.risk == :write
      assert editor.allowed_tools == []
    end
  end
end
