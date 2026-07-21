defmodule Jido.Connect.PostHog.CatalogPacksTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Catalog
  alias Jido.Connect.PostHog
  alias Jido.Connect.PostHog.ScopeResolver

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

      # Query (read)
      assert "posthog.query.run" in ids

      # Feature flag reads
      assert "posthog.feature_flag.evaluate" in ids
      assert "posthog.feature_flag.list" in ids
      assert "posthog.feature_flag.get" in ids

      # Write actions should not be in reader pack
      refute "posthog.event.capture" in ids
      refute "posthog.event.batch_capture" in ids
    end

    test "describe_tool accepts reader tools and rejects write tools" do
      reader_tools = [
        "posthog.event.list",
        "posthog.event.get",
        "posthog.person.get",
        "posthog.insight.get",
        "posthog.query.run",
        "posthog.feature_flag.list"
      ]

      for tool_id <- reader_tools do
        assert {:ok, descriptor} =
                 Catalog.describe_tool(tool_id,
                   modules: [PostHog],
                   packs: PostHog.catalog_packs(),
                   pack: :posthog_reader
                 )

        assert descriptor.tool.id == tool_id
      end

      # Write tools rejected from reader pack
      for tool_id <- ["posthog.event.capture", "posthog.event.batch_capture"] do
        assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
                 Catalog.describe_tool(tool_id,
                   modules: [PostHog],
                   packs: PostHog.catalog_packs(),
                   pack: :posthog_reader
                 )
      end
    end
  end

  describe "writer pack" do
    test "exposes only event capture write tools" do
      results =
        Catalog.search_tools("posthog",
          modules: [PostHog],
          packs: PostHog.catalog_packs(),
          pack: :posthog_writer
        )

      ids = Enum.map(results, & &1.tool.id)

      # Write tools
      assert "posthog.event.capture" in ids
      assert "posthog.event.batch_capture" in ids

      # Read tools should not be in writer pack
      refute "posthog.event.list" in ids
      refute "posthog.event.get" in ids
      refute "posthog.person.list" in ids
      refute "posthog.person.get" in ids
      refute "posthog.insight.list" in ids
      refute "posthog.insight.get" in ids
      refute "posthog.query.run" in ids
      refute "posthog.feature_flag.evaluate" in ids
      refute "posthog.feature_flag.list" in ids
      refute "posthog.feature_flag.get" in ids
    end

    test "describe_tool accepts writer tools and rejects read tools" do
      assert {:ok, descriptor} =
               Catalog.describe_tool("posthog.event.capture",
                 modules: [PostHog],
                 packs: PostHog.catalog_packs(),
                 pack: :posthog_writer
               )

      assert descriptor.tool.id == "posthog.event.capture"

      assert {:ok, descriptor} =
               Catalog.describe_tool("posthog.event.batch_capture",
                 modules: [PostHog],
                 packs: PostHog.catalog_packs(),
                 pack: :posthog_writer
               )

      assert descriptor.tool.id == "posthog.event.batch_capture"

      # Read tools rejected from writer pack
      assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
               Catalog.describe_tool("posthog.event.list",
                 modules: [PostHog],
                 packs: PostHog.catalog_packs(),
                 pack: :posthog_writer
               )

      assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
               Catalog.describe_tool("posthog.query.run",
                 modules: [PostHog],
                 packs: PostHog.catalog_packs(),
                 pack: :posthog_writer
               )
    end
  end

  describe "scope/policy matrix" do
    test "every registered action maps to a non-empty scope set" do
      spec = PostHog.integration()

      for action <- spec.actions do
        scopes = ScopeResolver.required_scopes(%{id: action.id}, %{}, %{})
        assert scopes != [], "action #{action.id} has no scope mapping"
      end
    end

    test "reader tools require read-only scopes" do
      read_scopes =
        [
          {"posthog.event.list", ["events:read"]},
          {"posthog.event.get", ["events:read"]},
          {"posthog.person.list", ["persons:read"]},
          {"posthog.person.get", ["persons:read"]},
          {"posthog.insight.list", ["insights:read"]},
          {"posthog.insight.get", ["insights:read"]},
          {"posthog.query.run", ["insights:read"]},
          {"posthog.feature_flag.evaluate", ["feature_flags:read"]},
          {"posthog.feature_flag.list", ["feature_flags:read"]},
          {"posthog.feature_flag.get", ["feature_flags:read"]}
        ]

      for {action_id, expected} <- read_scopes do
        assert ScopeResolver.required_scopes(%{id: action_id}, %{}, %{}) == expected
      end
    end

    test "writer tools require write scopes" do
      write_scopes = [
        {"posthog.event.capture", ["events:write"]},
        {"posthog.event.batch_capture", ["events:write"]}
      ]

      for {action_id, expected} <- write_scopes do
        assert ScopeResolver.required_scopes(%{id: action_id}, %{}, %{}) == expected
      end
    end

    test "unknown operation returns empty scope set" do
      assert ScopeResolver.required_scopes(%{id: "posthog.unknown.action"}, %{}, %{}) == []
    end

    test "project_api_key profile covers only read scopes by default" do
      spec = PostHog.integration()

      project_profile =
        Enum.find(spec.auth_profiles, &(&1.id == :project_api_key))

      assert "events:read" in project_profile.default_scopes
      assert "persons:read" in project_profile.default_scopes
      assert "insights:read" in project_profile.default_scopes
      refute "events:write" in project_profile.default_scopes
      refute "feature_flags:read" in project_profile.scopes
    end

    test "personal_api_key profile covers all declared scopes" do
      spec = PostHog.integration()

      personal_profile =
        Enum.find(spec.auth_profiles, &(&1.id == :personal_api_key))

      all_declared = personal_profile.scopes

      assert "events:read" in all_declared
      assert "events:write" in all_declared
      assert "persons:read" in all_declared
      assert "persons:write" in all_declared
      assert "insights:read" in all_declared
      assert "feature_flags:read" in all_declared
      assert "feature_flags:write" in all_declared
    end
  end

  describe "tool availability" do
    test "reports connection_required for all tools with no connection" do
      spec = PostHog.integration()
      plugin_module = PostHog.jido_plugin_module()
      tool_ids = Enum.map(spec.actions, & &1.id)

      availability =
        plugin_module.tool_availability()
        |> Map.new(&{&1.tool, &1})

      assert MapSet.new(Map.keys(availability)) == MapSet.new(tool_ids)

      for {_tool, avail} <- availability do
        assert avail.state == :connection_required
      end
    end

    test "reports available when connected with full scopes" do
      spec = PostHog.integration()
      plugin_module = PostHog.jido_plugin_module()

      connection =
        Connect.Connection.new!(%{
          id: "posthog_conn",
          provider: :posthog,
          profile: :personal_api_key,
          tenant_id: "tenant_1",
          owner_type: :app_user,
          owner_id: "user_1",
          status: :connected,
          scopes: all_posthog_scopes(spec)
        })

      available =
        plugin_module.tool_availability(%{connection: connection})
        |> Map.new(&{&1.tool, &1})

      tool_ids = Enum.map(spec.actions, & &1.id)
      assert MapSet.new(Map.keys(available)) == MapSet.new(tool_ids)

      for {_tool, avail} <- available do
        assert avail.state == :available
        assert avail.connection_id == connection.id
        assert avail.missing_scopes == []
      end
    end

    test "reports missing_scopes for write tools when only read scopes granted" do
      _spec = PostHog.integration()
      plugin_module = PostHog.jido_plugin_module()

      connection =
        Connect.Connection.new!(%{
          id: "posthog_conn",
          provider: :posthog,
          profile: :project_api_key,
          tenant_id: "tenant_1",
          owner_type: :app_user,
          owner_id: "user_1",
          status: :connected,
          scopes: ["events:read", "persons:read", "insights:read"]
        })

      availability =
        plugin_module.tool_availability(%{connection: connection})
        |> Map.new(&{&1.tool, &1})

      # Read tools are available
      for tool_id <-
            [
              "posthog.event.list",
              "posthog.person.get",
              "posthog.insight.list",
              "posthog.query.run"
            ] do
        assert availability[tool_id].state == :available
      end

      # Write tools need events:write scope
      for tool_id <- ["posthog.event.capture", "posthog.event.batch_capture"] do
        avail = availability[tool_id]
        assert avail.state == :missing_scopes
        assert "events:write" in avail.missing_scopes
      end

      # Feature flag tools need feature_flags:read scope
      for tool_id <-
            [
              "posthog.feature_flag.evaluate",
              "posthog.feature_flag.list",
              "posthog.feature_flag.get"
            ] do
        avail = availability[tool_id]
        assert avail.state == :missing_scopes
        assert "feature_flags:read" in avail.missing_scopes
      end
    end
  end

  describe "pack delegates" do
    test "catalog_packs returns reader and writer packs" do
      packs = PostHog.catalog_packs()
      pack_ids = Enum.map(packs, & &1.id)

      assert :posthog_reader in pack_ids
      assert :posthog_writer in pack_ids
    end

    test "all packs reference posthog provider and correct package" do
      for pack <- PostHog.catalog_packs() do
        assert pack.filters == %{provider: :posthog}
        assert pack.metadata.package == :jido_connect_posthog
      end
    end

    test "reader pack carries read risk metadata" do
      reader =
        Enum.find(PostHog.catalog_packs(), &(&1.id == :posthog_reader))

      assert reader.metadata.risk == :read
    end

    test "writer pack carries write risk metadata" do
      writer =
        Enum.find(PostHog.catalog_packs(), &(&1.id == :posthog_writer))

      assert writer.metadata.risk == :write
    end
  end

  defp all_posthog_scopes(spec) do
    profile =
      Enum.find(spec.auth_profiles, &(&1.id == :personal_api_key)) ||
        List.first(spec.auth_profiles)

    operation_scopes =
      spec.actions
      |> Enum.concat(spec.triggers)
      |> Enum.flat_map(& &1.scopes)

    profile.default_scopes
    |> Enum.concat(profile.scopes)
    |> Enum.concat(operation_scopes)
    |> Enum.uniq()
  end
end
