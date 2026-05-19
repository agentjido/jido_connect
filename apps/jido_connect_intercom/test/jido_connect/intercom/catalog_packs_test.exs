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

    test "reader pack has read risk" do
      packs = Intercom.catalog_packs()
      reader = Enum.find(packs, &(&1.id == :intercom_reader))

      assert reader.metadata.risk == :read
      assert reader.allowed_tools == []
    end

    test "editor pack has write risk" do
      packs = Intercom.catalog_packs()
      editor = Enum.find(packs, &(&1.id == :intercom_editor))

      assert editor.metadata.risk == :write
      assert editor.allowed_tools == []
    end
  end
end
