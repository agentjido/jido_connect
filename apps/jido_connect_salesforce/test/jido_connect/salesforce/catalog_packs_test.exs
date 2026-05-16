defmodule Jido.Connect.Salesforce.CatalogPacksTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Catalog
  alias Jido.Connect.Salesforce

  describe "reader pack" do
    test "exposes only read tools" do
      results =
        Catalog.search_tools("salesforce",
          modules: [Salesforce],
          packs: Salesforce.catalog_packs(),
          pack: :salesforce_reader
        )

      ids = Enum.map(results, & &1.tool.id)

      # Contact reads
      assert "salesforce.contacts.contact.get" in ids
      assert "salesforce.contacts.contact.list" in ids

      # Write tools excluded
      refute "salesforce.contacts.contact.create" in ids
    end

    test "describe_tool accepts reader tools and rejects write tools" do
      assert {:ok, descriptor} =
               Catalog.describe_tool("salesforce.contacts.contact.get",
                 modules: [Salesforce],
                 packs: Salesforce.catalog_packs(),
                 pack: :salesforce_reader
               )

      assert descriptor.tool.id == "salesforce.contacts.contact.get"

      assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
               Catalog.describe_tool("salesforce.contacts.contact.create",
                 modules: [Salesforce],
                 packs: Salesforce.catalog_packs(),
                 pack: :salesforce_reader
               )
    end
  end

  describe "editor pack" do
    test "exposes read and write tools" do
      results =
        Catalog.search_tools("salesforce",
          modules: [Salesforce],
          packs: Salesforce.catalog_packs(),
          pack: :salesforce_editor
        )

      ids = Enum.map(results, & &1.tool.id)

      # All read tools
      assert "salesforce.contacts.contact.get" in ids
      assert "salesforce.contacts.contact.list" in ids

      # Write tools included
      assert "salesforce.contacts.contact.create" in ids
    end

    test "describe_tool accepts write tools" do
      assert {:ok, descriptor} =
               Catalog.describe_tool("salesforce.contacts.contact.create",
                 modules: [Salesforce],
                 packs: Salesforce.catalog_packs(),
                 pack: :salesforce_editor
               )

      assert descriptor.tool.id == "salesforce.contacts.contact.create"
    end
  end

  describe "pack delegates" do
    test "catalog_packs returns reader and editor packs" do
      packs = Salesforce.catalog_packs()
      pack_ids = Enum.map(packs, & &1.id)

      assert pack_ids == [:salesforce_reader, :salesforce_editor]
    end

    test "all packs reference salesforce provider and correct package" do
      for pack <- Salesforce.catalog_packs() do
        assert pack.filters == %{provider: :salesforce}
        assert pack.metadata.package == :jido_connect_salesforce
      end
    end
  end
end
