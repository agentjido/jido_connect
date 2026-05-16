defmodule Jido.Connect.HubSpot.CatalogPacksTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Catalog
  alias Jido.Connect.HubSpot

  describe "reader pack" do
    test "exposes only read tools" do
      results =
        Catalog.search_tools("hubspot",
          modules: [HubSpot],
          packs: HubSpot.catalog_packs(),
          pack: :hubspot_reader
        )

      ids = Enum.map(results, & &1.tool.id)

      # Contact reads
      assert "hubspot.contacts.contact.get" in ids
      assert "hubspot.contacts.contact.list" in ids
      assert "hubspot.contacts.contact.search" in ids

      # Company reads
      assert "hubspot.companies.company.get" in ids
      assert "hubspot.companies.company.list" in ids
      assert "hubspot.companies.company.search" in ids

      # Deal reads
      assert "hubspot.deals.deal.get" in ids
      assert "hubspot.deals.deal.list" in ids
      assert "hubspot.deals.deal.search" in ids

      # Write tools excluded
      refute "hubspot.contacts.contact.create" in ids
      refute "hubspot.contacts.contact.update" in ids
      refute "hubspot.deals.deal.create" in ids
      refute "hubspot.deals.deal.update" in ids
      refute "hubspot.notes.note.create" in ids
    end

    test "describe_tool accepts reader tools and rejects write tools" do
      assert {:ok, descriptor} =
               Catalog.describe_tool("hubspot.contacts.contact.get",
                 modules: [HubSpot],
                 packs: HubSpot.catalog_packs(),
                 pack: :hubspot_reader
               )

      assert descriptor.tool.id == "hubspot.contacts.contact.get"

      assert {:ok, descriptor} =
               Catalog.describe_tool("hubspot.deals.deal.search",
                 modules: [HubSpot],
                 packs: HubSpot.catalog_packs(),
                 pack: :hubspot_reader
               )

      assert descriptor.tool.id == "hubspot.deals.deal.search"

      assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
               Catalog.describe_tool("hubspot.contacts.contact.create",
                 modules: [HubSpot],
                 packs: HubSpot.catalog_packs(),
                 pack: :hubspot_reader
               )

      assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
               Catalog.describe_tool("hubspot.notes.note.create",
                 modules: [HubSpot],
                 packs: HubSpot.catalog_packs(),
                 pack: :hubspot_reader
               )
    end
  end

  describe "sales_editor pack" do
    test "exposes read, contact/deal write, and note tools" do
      results =
        Catalog.search_tools("hubspot",
          modules: [HubSpot],
          packs: HubSpot.catalog_packs(),
          pack: :hubspot_sales_editor
        )

      ids = Enum.map(results, & &1.tool.id)

      # All read tools
      assert "hubspot.contacts.contact.get" in ids
      assert "hubspot.contacts.contact.list" in ids
      assert "hubspot.contacts.contact.search" in ids
      assert "hubspot.companies.company.get" in ids
      assert "hubspot.companies.company.list" in ids
      assert "hubspot.companies.company.search" in ids
      assert "hubspot.deals.deal.get" in ids
      assert "hubspot.deals.deal.list" in ids
      assert "hubspot.deals.deal.search" in ids

      # Write tools included
      assert "hubspot.contacts.contact.create" in ids
      assert "hubspot.contacts.contact.update" in ids
      assert "hubspot.deals.deal.create" in ids
      assert "hubspot.deals.deal.update" in ids
      assert "hubspot.notes.note.create" in ids
    end

    test "describe_tool accepts write tools" do
      assert {:ok, descriptor} =
               Catalog.describe_tool("hubspot.contacts.contact.create",
                 modules: [HubSpot],
                 packs: HubSpot.catalog_packs(),
                 pack: :hubspot_sales_editor
               )

      assert descriptor.tool.id == "hubspot.contacts.contact.create"

      assert {:ok, descriptor} =
               Catalog.describe_tool("hubspot.deals.deal.update",
                 modules: [HubSpot],
                 packs: HubSpot.catalog_packs(),
                 pack: :hubspot_sales_editor
               )

      assert descriptor.tool.id == "hubspot.deals.deal.update"

      assert {:ok, descriptor} =
               Catalog.describe_tool("hubspot.notes.note.create",
                 modules: [HubSpot],
                 packs: HubSpot.catalog_packs(),
                 pack: :hubspot_sales_editor
               )

      assert descriptor.tool.id == "hubspot.notes.note.create"
    end
  end

  describe "pack delegates" do
    test "catalog_packs returns reader and sales_editor packs" do
      packs = HubSpot.catalog_packs()
      pack_ids = Enum.map(packs, & &1.id)

      assert pack_ids == [:hubspot_reader, :hubspot_sales_editor]
    end

    test "all packs reference hubspot provider and correct package" do
      for pack <- HubSpot.catalog_packs() do
        assert pack.filters == %{provider: :hubspot}
        assert pack.metadata.package == :jido_connect_hubspot
      end
    end
  end
end
