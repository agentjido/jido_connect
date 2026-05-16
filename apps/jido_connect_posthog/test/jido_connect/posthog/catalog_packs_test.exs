defmodule Jido.Connect.PostHog.CatalogPacksTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Catalog
  alias Jido.Connect.PostHog

  describe "reader pack" do
    test "exposes only read tools" do
      results =
        Catalog.search_tools("posthog",
          modules: [PostHog],
          packs: PostHog.catalog_packs(),
          pack: :posthog_reader
        )

      ids = Enum.map(results, & &1.tool.id)

      # Event reads
      assert "posthog.event.list" in ids
      assert "posthog.event.get" in ids

      # Person reads
      assert "posthog.person.list" in ids
      assert "posthog.person.get" in ids

      # Insight reads
      assert "posthog.insight.list" in ids
      assert "posthog.insight.get" in ids
    end

    test "describe_tool accepts reader tools" do
      assert {:ok, descriptor} =
               Catalog.describe_tool("posthog.event.list",
                 modules: [PostHog],
                 packs: PostHog.catalog_packs(),
                 pack: :posthog_reader
               )

      assert descriptor.tool.id == "posthog.event.list"

      assert {:ok, descriptor} =
               Catalog.describe_tool("posthog.person.get",
                 modules: [PostHog],
                 packs: PostHog.catalog_packs(),
                 pack: :posthog_reader
               )

      assert descriptor.tool.id == "posthog.person.get"

      assert {:ok, descriptor} =
               Catalog.describe_tool("posthog.insight.get",
                 modules: [PostHog],
                 packs: PostHog.catalog_packs(),
                 pack: :posthog_reader
               )

      assert descriptor.tool.id == "posthog.insight.get"
    end
  end

  describe "pack delegates" do
    test "catalog_packs returns reader pack" do
      packs = PostHog.catalog_packs()
      pack_ids = Enum.map(packs, & &1.id)

      assert :posthog_reader in pack_ids
    end

    test "all packs reference posthog provider and correct package" do
      for pack <- PostHog.catalog_packs() do
        assert pack.filters == %{provider: :posthog}
        assert pack.metadata.package == :jido_connect_posthog
      end
    end
  end
end
