defmodule Jido.Connect.PostHogTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.PostHog

  @posthog_events_fragment Jido.Connect.PostHog.Actions.Events
  @posthog_event_capture_fragment Jido.Connect.PostHog.Actions.EventCapture
  @posthog_persons_fragment Jido.Connect.PostHog.Actions.Persons
  @posthog_insights_fragment Jido.Connect.PostHog.Actions.Insights
  @posthog_feature_flags_fragment Jido.Connect.PostHog.Actions.FeatureFlags

  @posthog_query_fragment Jido.Connect.PostHog.Actions.Query

  @posthog_action_modules [
    Jido.Connect.PostHog.Actions.ListEvents,
    Jido.Connect.PostHog.Actions.GetEvent,
    Jido.Connect.PostHog.Actions.CaptureEvent,
    Jido.Connect.PostHog.Actions.BatchCaptureEvents,
    Jido.Connect.PostHog.Actions.ListPersons,
    Jido.Connect.PostHog.Actions.GetPerson,
    Jido.Connect.PostHog.Actions.ListInsights,
    Jido.Connect.PostHog.Actions.GetInsight,
    Jido.Connect.PostHog.Actions.RunQuery,
    Jido.Connect.PostHog.Actions.EvaluateFeatureFlag,
    Jido.Connect.PostHog.Actions.ListFeatureFlags,
    Jido.Connect.PostHog.Actions.GetFeatureFlag
  ]

  @posthog_dsl_fragments [
    @posthog_events_fragment,
    @posthog_event_capture_fragment,
    @posthog_persons_fragment,
    @posthog_insights_fragment,
    @posthog_query_fragment,
    @posthog_feature_flags_fragment
  ]

  test "declares PostHog provider metadata" do
    spec = PostHog.integration()

    assert spec.id == :posthog
    assert spec.package == :jido_connect_posthog
    assert spec.name == "PostHog"
    assert spec.category == :data
    assert spec.status == :experimental
    assert spec.tags == [:analytics, :events, :feature_flags, :product_analytics]

    assert Enum.map(spec.actions, & &1.id) == [
             "posthog.event.list",
             "posthog.event.get",
             "posthog.event.capture",
             "posthog.event.batch_capture",
             "posthog.person.list",
             "posthog.person.get",
             "posthog.insight.list",
             "posthog.insight.get",
             "posthog.query.run",
             "posthog.feature_flag.evaluate",
             "posthog.feature_flag.list",
             "posthog.feature_flag.get"
           ]

    assert [] = spec.triggers

    assert [
             %{id: :project_api_key, kind: :api_key} = project_profile,
             %{id: :personal_api_key, kind: :api_key} = personal_profile
           ] =
             spec.auth_profiles

    assert project_profile.default? == true
    assert "events:read" in project_profile.default_scopes
    assert "persons:read" in project_profile.default_scopes
    assert "insights:read" in project_profile.default_scopes

    assert personal_profile.default? == false
    assert "events:write" in personal_profile.scopes
    assert "feature_flags:write" in personal_profile.scopes
  end

  test "catalog entry exposes auth capabilities" do
    entry = Connect.Catalog.entry(PostHog)
    features = entry.capabilities |> Enum.map(& &1.feature) |> MapSet.new()

    assert entry.package == :jido_connect_posthog
    assert entry.tags == [:analytics, :events, :feature_flags, :product_analytics]
    assert MapSet.member?(features, :api_key)
    assert MapSet.member?(features, :generated_jido_actions)
  end

  test "action specs resolve with correct metadata" do
    spec = PostHog.integration()

    assert {:ok,
            %{
              id: "posthog.event.list",
              resource: :event,
              verb: :list,
              mutation?: false,
              auth_profiles: [:project_api_key, :personal_api_key]
            }} =
             Connect.action(spec, "posthog.event.list")

    assert {:ok,
            %{
              id: "posthog.event.get",
              resource: :event,
              verb: :get,
              mutation?: false,
              auth_profiles: [:project_api_key, :personal_api_key]
            }} =
             Connect.action(spec, "posthog.event.get")

    assert {:ok,
            %{
              id: "posthog.person.list",
              resource: :person,
              verb: :list,
              mutation?: false,
              auth_profiles: [:project_api_key, :personal_api_key]
            }} =
             Connect.action(spec, "posthog.person.list")

    assert {:ok,
            %{
              id: "posthog.person.get",
              resource: :person,
              verb: :get,
              mutation?: false,
              auth_profiles: [:project_api_key, :personal_api_key]
            }} =
             Connect.action(spec, "posthog.person.get")

    assert {:ok,
            %{
              id: "posthog.insight.list",
              resource: :insight,
              verb: :list,
              mutation?: false,
              auth_profiles: [:project_api_key, :personal_api_key]
            }} =
             Connect.action(spec, "posthog.insight.list")

    assert {:ok,
            %{
              id: "posthog.insight.get",
              resource: :insight,
              verb: :get,
              mutation?: false,
              auth_profiles: [:project_api_key, :personal_api_key]
            }} =
             Connect.action(spec, "posthog.insight.get")
  end

  test "compiles generated Jido plugin surface" do
    assert Application.get_env(:jido_connect_posthog, :jido_connect_providers) == [PostHog]

    assert PostHog.jido_action_modules() == @posthog_action_modules
    assert [] = PostHog.jido_sensor_modules()
    assert PostHog.jido_plugin_module() == Jido.Connect.PostHog.Plugin

    assert %Connect.Catalog.Manifest{
             id: :posthog,
             package: :jido_connect_posthog,
             generated_modules: %{
               actions: @posthog_action_modules,
               sensors: [],
               plugin: Jido.Connect.PostHog.Plugin
             }
           } = PostHog.jido_connect_manifest()

    assert %Jido.Plugin.Spec{
             name: "posthog",
             module: Jido.Connect.PostHog.Plugin,
             actions: @posthog_action_modules
           } = Jido.Connect.PostHog.Plugin.plugin_spec()
  end

  test "loads PostHog Spark DSL fragments" do
    for fragment <- @posthog_dsl_fragments do
      assert {:module, ^fragment} = Code.ensure_loaded(fragment)
      assert fragment.extensions() == [Jido.Connect.Dsl.Extension]
      assert fragment.opts() == [of: Jido.Connect]
      assert %{extensions: [Jido.Connect.Dsl.Extension]} = fragment.persisted()
      assert is_map(fragment.spark_dsl_config())

      assert [{_section, Jido.Connect.Dsl.Extension, Jido.Connect.Dsl.Extension}] =
               fragment.validate_sections()
    end
  end

  test "generated action modules load and export run/2" do
    for module <- @posthog_action_modules do
      assert {:module, ^module} = Code.ensure_loaded(module)
      assert function_exported?(module, :run, 2)
    end

    assert {:module, Jido.Connect.PostHog.Plugin} =
             Code.ensure_loaded(Jido.Connect.PostHog.Plugin)

    assert function_exported?(Jido.Connect.PostHog.Plugin, :plugin_spec, 1)
  end

  test "generated action metadata tracks the DSL action" do
    projection = Jido.Connect.PostHog.Actions.ListEvents.jido_connect_projection()

    assert projection.action_id == "posthog.event.list"
    assert projection.label == "List events"
    assert Enum.map(projection.input, & &1.name) == [:limit, :offset, :event, :distinct_id]

    assert Enum.map(projection.output, & &1.name) == [
             :events,
             :next
           ]

    assert projection.risk == :read
    assert projection.resource == :event
    assert projection.verb == :list
    assert projection.auth_profiles == [:project_api_key, :personal_api_key]
    assert projection.scope_resolver == Jido.Connect.PostHog.ScopeResolver

    assert Jido.Connect.PostHog.Actions.ListEvents.name() == "posthog_event_list"
  end

  describe "plugin tool availability" do
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
          profile: :project_api_key,
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
