defmodule Jido.Connect.LinearTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Linear

  @linear_actions_fragment Jido.Connect.Linear.Actions.Issues
  @linear_comments_fragment Jido.Connect.Linear.Actions.Comments
  @linear_teams_fragment Jido.Connect.Linear.Actions.Teams

  @linear_action_modules [
    Jido.Connect.Linear.Actions.GetIssue,
    Jido.Connect.Linear.Actions.SearchIssues,
    Jido.Connect.Linear.Actions.CreateIssue,
    Jido.Connect.Linear.Actions.UpdateIssue,
    Jido.Connect.Linear.Actions.AssignIssue,
    Jido.Connect.Linear.Actions.SetIssueStatus,
    Jido.Connect.Linear.Actions.SetIssueLabels,
    Jido.Connect.Linear.Actions.AddComment,
    Jido.Connect.Linear.Actions.ListComments,
    Jido.Connect.Linear.Actions.ListTeams,
    Jido.Connect.Linear.Actions.GetTeam
  ]

  @linear_sensor_modules [
    Jido.Connect.Linear.Sensors.IssueChanged,
    Jido.Connect.Linear.Sensors.CommentChanged
  ]

  @linear_triggers_fragment Jido.Connect.Linear.Triggers.Issues

  @linear_dsl_fragments [
    @linear_actions_fragment,
    @linear_comments_fragment,
    @linear_teams_fragment,
    @linear_triggers_fragment
  ]

  test "declares Linear provider metadata" do
    spec = Linear.integration()

    assert spec.id == :linear
    assert spec.package == :jido_connect_linear
    assert spec.name == "Linear"
    assert spec.category == :project_management
    assert spec.status == :experimental
    assert spec.tags == [:project_management, :issues, :work_management]

    assert Enum.map(spec.actions, & &1.id) == [
             "linear.issue.get",
             "linear.issue.search",
             "linear.issue.create",
             "linear.issue.update",
             "linear.issue.assign",
             "linear.issue.set_status",
             "linear.issue.set_labels",
             "linear.issue.comment.create",
             "linear.issue.comments.list",
             "linear.team.list",
             "linear.team.get"
           ]

    assert Enum.map(spec.triggers, & &1.id) == [
             "linear.issue.changed",
             "linear.comment.changed"
           ]

    assert [
             %{id: :api_key, kind: :api_key} = api_key_profile,
             %{id: :oauth2_user, kind: :oauth2} = oauth_profile
           ] =
             spec.auth_profiles

    assert api_key_profile.default? == true
    assert "read" in api_key_profile.default_scopes
    assert "write" in api_key_profile.scopes

    assert oauth_profile.default? == false
    assert oauth_profile.pkce? == true
    assert oauth_profile.refresh? == true
    assert "read" in oauth_profile.default_scopes
    assert "write" in oauth_profile.optional_scopes
  end

  test "declares team_access policy" do
    spec = Linear.integration()
    assert [%{id: :team_access, decision: :allow_operation}] = spec.policies
  end

  test "catalog entry exposes auth and runtime capabilities" do
    entry = Connect.Catalog.entry(Linear)
    features = entry.capabilities |> Enum.map(& &1.feature) |> MapSet.new()

    assert entry.package == :jido_connect_linear
    assert entry.tags == [:project_management, :issues, :work_management]
    assert [%{id: :team_access}] = entry.policies
    assert MapSet.subset?(MapSet.new([:api_key, :oauth2]), features)
    assert MapSet.member?(features, :generated_jido_actions)
    assert MapSet.member?(features, :webhook_verification)
  end

  test "action specs resolve with correct metadata" do
    spec = Linear.integration()

    assert {:ok,
            %{
              id: "linear.issue.get",
              resource: :issue,
              verb: :get,
              mutation?: false,
              auth_profiles: [:api_key, :oauth2_user],
              scope_resolver: Jido.Connect.Linear.ScopeResolver
            }} =
             Connect.action(spec, "linear.issue.get")

    assert {:ok,
            %{
              id: "linear.issue.search",
              resource: :issue,
              verb: :search,
              mutation?: false,
              auth_profiles: [:api_key, :oauth2_user],
              scope_resolver: Jido.Connect.Linear.ScopeResolver
            }} =
             Connect.action(spec, "linear.issue.search")

    assert {:ok,
            %{
              id: "linear.issue.create",
              resource: :issue,
              verb: :create,
              mutation?: true,
              confirmation: :required_for_ai,
              auth_profiles: [:api_key, :oauth2_user],
              scope_resolver: Jido.Connect.Linear.ScopeResolver
            }} =
             Connect.action(spec, "linear.issue.create")

    assert {:ok,
            %{
              id: "linear.issue.update",
              resource: :issue,
              verb: :update,
              mutation?: true,
              confirmation: :required_for_ai,
              auth_profiles: [:api_key, :oauth2_user],
              scope_resolver: Jido.Connect.Linear.ScopeResolver
            }} =
             Connect.action(spec, "linear.issue.update")

    assert {:ok,
            %{
              id: "linear.issue.comment.create",
              resource: :comment,
              verb: :create,
              mutation?: true,
              confirmation: :required_for_ai,
              auth_profiles: [:api_key, :oauth2_user],
              scope_resolver: Jido.Connect.Linear.ScopeResolver
            }} =
             Connect.action(spec, "linear.issue.comment.create")

    assert {:ok,
            %{
              id: "linear.team.list",
              resource: :team,
              verb: :list,
              mutation?: false,
              auth_profiles: [:api_key, :oauth2_user],
              scope_resolver: Jido.Connect.Linear.ScopeResolver
            }} =
             Connect.action(spec, "linear.team.list")

    assert {:ok,
            %{
              id: "linear.issue.comments.list",
              resource: :comment,
              verb: :list,
              mutation?: false,
              auth_profiles: [:api_key, :oauth2_user],
              scope_resolver: Jido.Connect.Linear.ScopeResolver
            }} =
             Connect.action(spec, "linear.issue.comments.list")

    assert {:ok,
            %{
              id: "linear.team.get",
              resource: :team,
              verb: :get,
              mutation?: false,
              auth_profiles: [:api_key, :oauth2_user],
              scope_resolver: Jido.Connect.Linear.ScopeResolver
            }} =
             Connect.action(spec, "linear.team.get")
  end

  test "compiles generated Jido plugin surface" do
    assert Application.get_env(:jido_connect_linear, :jido_connect_providers) == [Linear]

    assert Linear.jido_action_modules() == @linear_action_modules
    assert Linear.jido_sensor_modules() == @linear_sensor_modules
    assert Linear.jido_plugin_module() == Jido.Connect.Linear.Plugin

    assert %Connect.Catalog.Manifest{
             id: :linear,
             package: :jido_connect_linear,
             generated_modules: %{
               actions: @linear_action_modules,
               sensors: @linear_sensor_modules,
               plugin: Jido.Connect.Linear.Plugin
             }
           } = Linear.jido_connect_manifest()

    assert %Jido.Plugin.Spec{
             name: "linear",
             module: Jido.Connect.Linear.Plugin,
             actions: @linear_action_modules
           } = Jido.Connect.Linear.Plugin.plugin_spec()
  end

  test "loads Linear Spark DSL fragments" do
    for fragment <- @linear_dsl_fragments do
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
    for module <- @linear_action_modules do
      assert {:module, ^module} = Code.ensure_loaded(module)
      assert function_exported?(module, :run, 2)
    end

    assert {:module, Jido.Connect.Linear.Plugin} =
             Code.ensure_loaded(Jido.Connect.Linear.Plugin)

    assert function_exported?(Jido.Connect.Linear.Plugin, :plugin_spec, 1)
  end

  test "generated action metadata tracks the DSL action" do
    projection = Jido.Connect.Linear.Actions.GetIssue.jido_connect_projection()

    assert projection.action_id == "linear.issue.get"
    assert projection.label == "Get issue"
    assert Enum.map(projection.input, & &1.name) == [:issue_id, :fields]

    assert Enum.map(projection.output, & &1.name) == [
             :id,
             :identifier,
             :title,
             :description,
             :status,
             :priority,
             :team,
             :assignee,
             :labels,
             :created_at,
             :updated_at
           ]

    assert projection.risk == :read
    assert projection.resource == :issue
    assert projection.verb == :get
    assert projection.policies == [:team_access]
    assert projection.auth_profiles == [:api_key, :oauth2_user]
    assert projection.scope_resolver == Jido.Connect.Linear.ScopeResolver

    assert Jido.Connect.Linear.Actions.GetIssue.name() == "linear_issue_get"
  end

  describe "plugin tool availability" do
    test "reports connection_required for all tools with no connection" do
      spec = Linear.integration()
      plugin_module = Linear.jido_plugin_module()
      tool_ids = Enum.map(spec.actions ++ spec.triggers, & &1.id)

      availability =
        plugin_module.tool_availability()
        |> Map.new(&{&1.tool, &1})

      assert MapSet.new(Map.keys(availability)) == MapSet.new(tool_ids)

      for {_tool, avail} <- availability do
        assert avail.state == :connection_required
      end

      # Verify trigger availability
      assert availability["linear.issue.changed"].state == :connection_required
      assert availability["linear.comment.changed"].state == :connection_required
    end

    test "reports available when connected with full scopes" do
      spec = Linear.integration()
      plugin_module = Linear.jido_plugin_module()

      connection =
        Connect.Connection.new!(%{
          id: "linear_conn",
          provider: :linear,
          profile: :api_key,
          tenant_id: "tenant_1",
          owner_type: :app_user,
          owner_id: "user_1",
          status: :connected,
          scopes: all_linear_scopes(spec)
        })

      available =
        plugin_module.tool_availability(%{connection: connection})
        |> Map.new(&{&1.tool, &1})

      tool_ids = Enum.map(spec.actions ++ spec.triggers, & &1.id)
      assert MapSet.new(Map.keys(available)) == MapSet.new(tool_ids)

      for {_tool, avail} <- available do
        assert avail.state == :available
        assert avail.connection_id == connection.id
        assert avail.missing_scopes == []
      end
    end

    test "reports missing_scopes when connected without write scopes" do
      spec = Linear.integration()
      plugin_module = Linear.jido_plugin_module()

      read_scopes = ["read"]

      connection =
        Connect.Connection.new!(%{
          id: "linear_readonly_conn",
          provider: :linear,
          profile: :api_key,
          tenant_id: "tenant_1",
          owner_type: :app_user,
          owner_id: "user_1",
          status: :connected,
          scopes: read_scopes
        })

      availability =
        plugin_module.tool_availability(%{connection: connection})
        |> Map.new(&{&1.tool, &1})

      # Read actions should be available
      read_actions = Enum.filter(spec.actions, &(&1.risk == :read))

      for action <- read_actions do
        assert availability[action.id].state == :available
      end

      # Write actions should report missing scopes
      write_actions = Enum.filter(spec.actions, &(&1.risk in [:write, :external_write]))

      for action <- write_actions do
        assert availability[action.id].state == :missing_scopes
        assert length(availability[action.id].missing_scopes) > 0
      end
    end
  end

  defp all_linear_scopes(spec) do
    profile =
      Enum.find(spec.auth_profiles, &(&1.id == :api_key)) ||
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
