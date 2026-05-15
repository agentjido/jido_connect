defmodule Jido.Connect.Google.SearchConsole.CatalogPacksTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Catalog
  alias Jido.Connect.Google.SearchConsole

  @reader_tools [
    "google.search_console.search_analytics.query",
    "google.search_console.site.list",
    "google.search_console.sitemap.list",
    "google.search_console.url_inspection.inspect"
  ]

  @write_tools [
    "google.search_console.site.add",
    "google.search_console.sitemap.submit"
  ]

  describe "reader pack" do
    test "exposes all read-only tools" do
      results =
        Catalog.search_tools("search_console",
          modules: [SearchConsole],
          packs: SearchConsole.catalog_packs(),
          pack: :google_search_console_reader
        )

      ids = Enum.map(results, & &1.tool.id)

      for tool <- @reader_tools do
        assert tool in ids, "expected #{tool} in reader pack results"
      end
    end

    test "excludes write and admin tools" do
      results =
        Catalog.search_tools("search_console",
          modules: [SearchConsole],
          packs: SearchConsole.catalog_packs(),
          pack: :google_search_console_reader
        )

      ids = Enum.map(results, & &1.tool.id)

      for tool <- @write_tools do
        refute tool in ids, "expected #{tool} to be excluded from reader pack"
      end
    end

    test "allows describing a read-only tool" do
      assert {:ok, descriptor} =
               Catalog.describe_tool("google.search_console.search_analytics.query",
                 modules: [SearchConsole],
                 packs: SearchConsole.catalog_packs(),
                 pack: :google_search_console_reader
               )

      assert descriptor.tool.id == "google.search_console.search_analytics.query"
    end

    test "rejects describing a write tool" do
      assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
               Catalog.describe_tool("google.search_console.site.add",
                 modules: [SearchConsole],
                 packs: SearchConsole.catalog_packs(),
                 pack: :google_search_console_reader
               )
    end

    test "rejects describing a sitemap submit tool" do
      assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
               Catalog.describe_tool("google.search_console.sitemap.submit",
                 modules: [SearchConsole],
                 packs: SearchConsole.catalog_packs(),
                 pack: :google_search_console_reader
               )
    end
  end

  describe "seo pack" do
    test "exposes all read and write tools" do
      results =
        Catalog.search_tools("search_console",
          modules: [SearchConsole],
          packs: SearchConsole.catalog_packs(),
          pack: :google_search_console_seo
        )

      ids = Enum.map(results, & &1.tool.id)

      for tool <- @reader_tools ++ @write_tools do
        assert tool in ids, "expected #{tool} in SEO pack results"
      end
    end

    test "allows describing write tools" do
      assert {:ok, descriptor} =
               Catalog.describe_tool("google.search_console.site.add",
                 modules: [SearchConsole],
                 packs: SearchConsole.catalog_packs(),
                 pack: :google_search_console_seo
               )

      assert descriptor.tool.id == "google.search_console.site.add"

      assert {:ok, descriptor} =
               Catalog.describe_tool("google.search_console.sitemap.submit",
                 modules: [SearchConsole],
                 packs: SearchConsole.catalog_packs(),
                 pack: :google_search_console_seo
               )

      assert descriptor.tool.id == "google.search_console.sitemap.submit"
    end

    test "allows describing read tools" do
      assert {:ok, descriptor} =
               Catalog.describe_tool("google.search_console.search_analytics.query",
                 modules: [SearchConsole],
                 packs: SearchConsole.catalog_packs(),
                 pack: :google_search_console_seo
               )

      assert descriptor.tool.id == "google.search_console.search_analytics.query"

      assert {:ok, descriptor} =
               Catalog.describe_tool("google.search_console.url_inspection.inspect",
                 modules: [SearchConsole],
                 packs: SearchConsole.catalog_packs(),
                 pack: :google_search_console_seo
               )

      assert descriptor.tool.id == "google.search_console.url_inspection.inspect"
    end
  end

  describe "pack enumeration" do
    test "catalog_packs/0 returns reader and seo packs" do
      packs = SearchConsole.catalog_packs()

      assert length(packs) == 2
      assert Enum.find(packs, &(&1.id == :google_search_console_reader))
      assert Enum.find(packs, &(&1.id == :google_search_console_seo))
    end

    test "packs have correct risk metadata" do
      packs = SearchConsole.catalog_packs()
      reader = Enum.find(packs, &(&1.id == :google_search_console_reader))
      seo = Enum.find(packs, &(&1.id == :google_search_console_seo))

      assert reader.metadata.risk == :read
      assert seo.metadata.risk == :write
    end
  end
end
