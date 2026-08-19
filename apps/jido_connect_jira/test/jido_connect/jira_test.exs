defmodule Jido.Connect.JiraTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Jira

  defmodule PreviewWriteClient do
    def create_issue(_attrs, _request), do: unexpected_write()
    def update_issue(_issue_key, _attrs, _request), do: unexpected_write()
    def transition_issue(_issue_key, _transition_id, _request, _opts), do: unexpected_write()
    def assign_issue(_issue_key, _account_id, _request), do: unexpected_write()

    defp unexpected_write do
      send(self(), :jira_preview_called_provider)
      {:error, :unexpected_write}
    end
  end

  @jira_actions_fragment Jido.Connect.Jira.Actions.Issues
  @jira_projects_fragment Jido.Connect.Jira.Actions.Projects
  @jira_metadata_fragment Jido.Connect.Jira.Actions.Metadata
  @jira_boards_fragment Jido.Connect.Jira.Actions.Boards
  @jira_filters_fragment Jido.Connect.Jira.Actions.Filters
  @jira_plans_fragment Jido.Connect.Jira.Actions.Plans

  @jira_action_modules [
    Jido.Connect.Jira.Actions.GetIssue,
    Jido.Connect.Jira.Actions.ListIssues,
    Jido.Connect.Jira.Actions.CreateIssue,
    Jido.Connect.Jira.Actions.UpdateIssue,
    Jido.Connect.Jira.Actions.TransitionIssue,
    Jido.Connect.Jira.Actions.ListIssueTransitions,
    Jido.Connect.Jira.Actions.DeleteIssue,
    Jido.Connect.Jira.Actions.AssignIssue,
    Jido.Connect.Jira.Actions.AddComment,
    Jido.Connect.Jira.Actions.ListProjects,
    Jido.Connect.Jira.Actions.GetProject,
    Jido.Connect.Jira.Actions.ListFieldSchemas,
    Jido.Connect.Jira.Actions.ListBoards,
    Jido.Connect.Jira.Actions.GetBoard,
    Jido.Connect.Jira.Actions.CreateBoard,
    Jido.Connect.Jira.Actions.ListFilters,
    Jido.Connect.Jira.Actions.GetFilter,
    Jido.Connect.Jira.Actions.CreateFilter,
    Jido.Connect.Jira.Actions.UpdateFilter,
    Jido.Connect.Jira.Actions.GetFilterColumns,
    Jido.Connect.Jira.Actions.UpdateFilterColumns,
    Jido.Connect.Jira.Actions.UpdateFilterShare,
    Jido.Connect.Jira.Actions.ListPlans,
    Jido.Connect.Jira.Actions.GetPlan,
    Jido.Connect.Jira.Actions.CreatePlan,
    Jido.Connect.Jira.Actions.UpdatePlan,
    Jido.Connect.Jira.Actions.DuplicatePlan,
    Jido.Connect.Jira.Actions.ArchivePlan,
    Jido.Connect.Jira.Actions.TrashPlan
  ]

  @jira_sensor_modules [
    Jido.Connect.Jira.Sensors.IssueChanged,
    Jido.Connect.Jira.Sensors.CommentChanged
  ]

  @jira_triggers_fragment Jido.Connect.Jira.Triggers.Issues

  @jira_dsl_fragments [
    @jira_actions_fragment,
    @jira_projects_fragment,
    @jira_metadata_fragment,
    @jira_boards_fragment,
    @jira_filters_fragment,
    @jira_plans_fragment,
    @jira_triggers_fragment
  ]

  test "declares Jira provider metadata" do
    spec = Jira.integration()

    assert spec.id == :jira
    assert spec.package == :jido_connect_jira
    assert spec.name == "Jira"
    assert spec.category == :project_management
    assert spec.status == :experimental
    assert spec.tags == [:project_management, :issues, :work_management]

    assert Enum.map(spec.actions, & &1.id) == [
             "jira.issue.get",
             "jira.issue.search",
             "jira.issue.create",
             "jira.issue.update",
             "jira.issue.transition",
             "jira.issue.transition.list",
             "jira.issue.delete",
             "jira.issue.assign",
             "jira.issue.comment.create",
             "jira.project.list",
             "jira.project.get",
             "jira.field_schema.list",
             "jira.board.list",
             "jira.board.get",
             "jira.board.create",
             "jira.filter.list",
             "jira.filter.get",
             "jira.filter.create",
             "jira.filter.update",
             "jira.filter.columns.get",
             "jira.filter.columns.update",
             "jira.filter.share.update",
             "jira.plan.list",
             "jira.plan.get",
             "jira.plan.create",
             "jira.plan.update",
             "jira.plan.duplicate",
             "jira.plan.archive",
             "jira.plan.trash"
           ]

    assert Enum.map(spec.triggers, & &1.id) == [
             "jira.issue.changed",
             "jira.comment.changed"
           ]

    assert [
             %{id: :api_token, kind: :api_key} = api_token_profile,
             %{id: :oauth2_user, kind: :oauth2} = oauth_profile
           ] =
             spec.auth_profiles

    assert api_token_profile.default? == true
    assert api_token_profile.credential_fields == [:email, :api_token]
    assert api_token_profile.lease_fields == [:email, :api_token]
    assert "read:jira-work" in api_token_profile.default_scopes
    assert "write:jira-work" in api_token_profile.scopes

    assert oauth_profile.default? == false
    assert oauth_profile.pkce? == true
    assert oauth_profile.refresh? == true
    assert "read:jira-work" in oauth_profile.default_scopes
    assert "write:jira-work" in oauth_profile.optional_scopes
  end

  test "declares project and Jira administration policies" do
    spec = Jira.integration()

    assert [
             %{id: :project_access, decision: :allow_operation},
             %{id: :jira_admin_access, decision: :allow_operation}
           ] = spec.policies
  end

  test "passes injected clients as runtime infrastructure" do
    runtime = Jido.Connect.Jira.TestRuntime.build()

    lease =
      Connect.CredentialLease.from_connection!(
        runtime.context.connection,
        runtime.credentials,
        expires_at: DateTime.add(DateTime.utc_now(), 60, :second)
      )

    assert {:ok, %{projects: [%{key: "PROJ"}, %{key: "TEAM"}]}} =
             Connect.invoke(Jira, "jira.project.list", %{},
               context: runtime.context,
               credential_lease: lease,
               provider_client: Jido.Connect.Jira.MockClient
             )
  end

  test "validates normalized issue results against the strict declared output" do
    runtime = Jido.Connect.Jira.TestRuntime.build()

    lease =
      Connect.CredentialLease.from_connection!(
        runtime.context.connection,
        runtime.credentials,
        expires_at: DateTime.add(DateTime.utc_now(), 60, :second)
      )

    assert {:ok, issue} =
             Connect.invoke(Jira, "jira.issue.get", %{issue_key: "PROJ-123"},
               context: runtime.context,
               credential_lease: lease,
               provider_client: Jido.Connect.Jira.MockClient
             )

    assert issue.key == "PROJ-123"
    assert issue.summary == "Test issue"
    refute Map.has_key?(issue, :id)
    refute Map.has_key?(issue, :url)
    refute Map.has_key?(issue, :issue_type)
  end

  test "prepares a safe Jira comment preview without calling the provider" do
    runtime = Jido.Connect.Jira.TestRuntime.build()

    lease =
      Connect.CredentialLease.from_connection!(
        runtime.context.connection,
        runtime.credentials,
        expires_at: DateTime.add(DateTime.utc_now(), 60, :second)
      )

    assert {:ok, prepared} =
             Connect.prepare(
               Jira,
               "jira.issue.comment.create",
               %{issue_key: "PROJ-123", body: "Ready for review"},
               context: runtime.context,
               credential_lease: lease
             )

    assert prepared.preview["issue_key"] == "PROJ-123"
    assert prepared.preview["comment_bytes"] == 16
    assert prepared.preview.action_id == "jira.issue.comment.create"
  end

  test "prepares safe issue write previews without calling the provider" do
    runtime = Jido.Connect.Jira.TestRuntime.build()

    lease =
      Connect.CredentialLease.from_connection!(
        runtime.context.connection,
        runtime.credentials,
        expires_at: DateTime.add(DateTime.utc_now(), 60, :second)
      )

    cases = [
      {
        "jira.issue.create",
        %{
          project_key: "PROJ",
          issue_type: "Task",
          summary: "Review the action plane",
          description: "Private text",
          labels: ["review"]
        },
        %{
          "operation" => "create",
          "project_key" => "PROJ",
          "issue_type" => "Task",
          "summary" => "Review the action plane",
          "description_bytes" => 12,
          "label_count" => 1
        }
      },
      {
        "jira.issue.update",
        %{issue_key: "PROJ-123", summary: "Updated summary", description: "Private text"},
        %{
          "operation" => "update",
          "issue_key" => "PROJ-123",
          "changed_fields" => ["description", "summary"],
          "summary" => "Updated summary",
          "description_bytes" => 12
        }
      },
      {
        "jira.issue.transition",
        %{
          issue_key: "PROJ-123",
          transition_id: "21",
          fields: %{"resolution" => "Done"}
        },
        %{
          "operation" => "transition",
          "issue_key" => "PROJ-123",
          "transition_id" => "21",
          "field_names" => ["resolution"]
        }
      },
      {
        "jira.issue.assign",
        %{issue_key: "PROJ-123", account_id: "account-42"},
        %{
          "operation" => "assign",
          "issue_key" => "PROJ-123",
          "account_id" => "account-42"
        }
      }
    ]

    for {action_id, input, expected} <- cases do
      assert {:ok, prepared} =
               Connect.prepare(Jira, action_id, input,
                 context: runtime.context,
                 credential_lease: lease,
                 provider_client: PreviewWriteClient
               )

      assert Map.take(prepared.preview, Map.keys(expected)) == expected
      assert prepared.preview.action_id == action_id
      refute inspect(prepared.preview) =~ "Private text"
    end

    refute_received :jira_preview_called_provider
  end

  test "catalog entry exposes auth and runtime capabilities" do
    entry = Connect.Catalog.entry(Jira)
    features = entry.capabilities |> Enum.map(& &1.feature) |> MapSet.new()

    assert entry.package == :jido_connect_jira
    assert entry.tags == [:project_management, :issues, :work_management]
    assert [%{id: :project_access}, %{id: :jira_admin_access}] = entry.policies
    assert MapSet.subset?(MapSet.new([:api_key, :oauth2]), features)
    assert MapSet.member?(features, :generated_jido_actions)
    assert MapSet.member?(features, :webhook_verification)
  end

  test "action specs resolve with correct metadata" do
    spec = Jira.integration()

    assert {:ok,
            %{
              id: "jira.issue.get",
              resource: :issue,
              verb: :get,
              mutation?: false,
              auth_profiles: [:api_token, :oauth2_user],
              scope_resolver: Jido.Connect.Jira.ScopeResolver
            }} =
             Connect.action(spec, "jira.issue.get")

    assert {:ok,
            %{
              id: "jira.issue.search",
              resource: :issue,
              verb: :search,
              mutation?: false,
              auth_profiles: [:api_token, :oauth2_user],
              scope_resolver: Jido.Connect.Jira.ScopeResolver
            }} =
             Connect.action(spec, "jira.issue.search")

    assert {:ok,
            %{
              id: "jira.issue.create",
              resource: :issue,
              verb: :create,
              mutation?: true,
              confirmation: :required_for_ai,
              auth_profiles: [:api_token, :oauth2_user],
              scope_resolver: Jido.Connect.Jira.ScopeResolver
            }} =
             Connect.action(spec, "jira.issue.create")

    assert {:ok,
            %{
              id: "jira.issue.update",
              resource: :issue,
              verb: :update,
              mutation?: true,
              confirmation: :required_for_ai,
              auth_profiles: [:api_token, :oauth2_user],
              scope_resolver: Jido.Connect.Jira.ScopeResolver
            }} =
             Connect.action(spec, "jira.issue.update")

    assert {:ok,
            %{
              id: "jira.issue.transition",
              resource: :issue,
              verb: :update,
              mutation?: true,
              confirmation: :required_for_ai,
              auth_profiles: [:api_token, :oauth2_user],
              scope_resolver: Jido.Connect.Jira.ScopeResolver
            }} =
             Connect.action(spec, "jira.issue.transition")

    assert {:ok,
            %{
              id: "jira.issue.assign",
              resource: :issue,
              verb: :update,
              mutation?: true,
              confirmation: :required_for_ai,
              auth_profiles: [:api_token, :oauth2_user],
              scope_resolver: Jido.Connect.Jira.ScopeResolver
            }} =
             Connect.action(spec, "jira.issue.assign")

    assert {:ok,
            %{
              id: "jira.issue.comment.create",
              resource: :comment,
              verb: :create,
              mutation?: true,
              confirmation: :required_for_ai,
              auth_profiles: [:api_token, :oauth2_user],
              scope_resolver: Jido.Connect.Jira.ScopeResolver
            }} =
             Connect.action(spec, "jira.issue.comment.create")

    assert {:ok,
            %{
              id: "jira.project.list",
              resource: :project,
              verb: :list,
              mutation?: false,
              auth_profiles: [:api_token, :oauth2_user],
              scope_resolver: Jido.Connect.Jira.ScopeResolver
            }} =
             Connect.action(spec, "jira.project.list")

    assert {:ok,
            %{
              id: "jira.project.get",
              resource: :project,
              verb: :get,
              mutation?: false,
              auth_profiles: [:api_token, :oauth2_user],
              scope_resolver: Jido.Connect.Jira.ScopeResolver
            }} =
             Connect.action(spec, "jira.project.get")

    assert {:ok,
            %{
              id: "jira.field_schema.list",
              resource: :field_schema,
              verb: :list,
              mutation?: false,
              auth_profiles: [:api_token, :oauth2_user],
              scope_resolver: Jido.Connect.Jira.ScopeResolver
            }} =
             Connect.action(spec, "jira.field_schema.list")
  end

  test "compiles generated Jido plugin surface" do
    assert Application.get_env(:jido_connect_jira, :jido_connect_providers) == [Jira]

    assert Jira.jido_action_modules() == @jira_action_modules
    assert Jira.jido_sensor_modules() == @jira_sensor_modules
    assert Jira.jido_plugin_module() == Jido.Connect.Jira.Plugin

    assert %Connect.Catalog.Manifest{
             id: :jira,
             package: :jido_connect_jira,
             generated_modules: %{
               actions: @jira_action_modules,
               sensors: @jira_sensor_modules,
               plugin: Jido.Connect.Jira.Plugin
             }
           } = Jira.jido_connect_manifest()

    assert %Jido.Plugin.Spec{
             name: "jira",
             module: Jido.Connect.Jira.Plugin,
             actions: @jira_action_modules
           } = Jido.Connect.Jira.Plugin.plugin_spec()
  end

  test "loads Jira Spark DSL fragments" do
    for fragment <- @jira_dsl_fragments do
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
    for module <- @jira_action_modules do
      assert {:module, ^module} = Code.ensure_loaded(module)
      assert function_exported?(module, :run, 2)
      assert module.operation_id() == module.jido_connect_projection().action_id

      assert {:error, %Connect.Error.AuthError{reason: :context_required}} =
               module.run(%{}, %{})
    end

    assert {:module, Jido.Connect.Jira.Plugin} = Code.ensure_loaded(Jido.Connect.Jira.Plugin)
    assert function_exported?(Jido.Connect.Jira.Plugin, :plugin_spec, 1)
  end

  test "generated action metadata tracks the DSL action" do
    projection = Jido.Connect.Jira.Actions.GetIssue.jido_connect_projection()

    assert projection.action_id == "jira.issue.get"
    assert projection.label == "Get issue"
    assert Enum.map(projection.input, & &1.name) == [:issue_key, :fields]

    assert Enum.map(projection.output, & &1.name) == [
             :key,
             :summary,
             :status,
             :project,
             :assignee,
             :priority,
             :labels,
             :created_at,
             :updated_at
           ]

    assert projection.risk == :read
    assert projection.resource == :issue
    assert projection.verb == :get
    assert projection.policies == [:project_access]
    assert projection.auth_profiles == [:api_token, :oauth2_user]
    assert projection.scope_resolver == Jido.Connect.Jira.ScopeResolver

    assert Jido.Connect.Jira.Actions.GetIssue.name() == "jira_issue_get"
  end

  describe "plugin tool availability" do
    test "reports connection_required for all tools with no connection" do
      spec = Jira.integration()
      plugin_module = Jira.jido_plugin_module()
      tool_ids = Enum.map(spec.actions ++ spec.triggers, & &1.id)

      availability =
        plugin_module.tool_availability()
        |> Map.new(&{&1.tool, &1})

      assert MapSet.new(Map.keys(availability)) == MapSet.new(tool_ids)

      for {_tool, avail} <- availability do
        assert avail.state == :connection_required
      end

      # Verify trigger availability
      assert availability["jira.issue.changed"].state == :connection_required
      assert availability["jira.comment.changed"].state == :connection_required
    end

    test "reports available when connected with full scopes" do
      spec = Jira.integration()
      plugin_module = Jira.jido_plugin_module()

      connection =
        Connect.Connection.new!(%{
          id: "jira_conn",
          provider: :jira,
          profile: :api_token,
          tenant_id: "tenant_1",
          owner_type: :app_user,
          owner_id: "user_1",
          status: :connected,
          scopes: all_jira_scopes(spec)
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
      spec = Jira.integration()
      plugin_module = Jira.jido_plugin_module()

      read_scopes = [
        "read:jira-work",
        "read:jira-users",
        "read:jira-configuration"
      ]

      connection =
        Connect.Connection.new!(%{
          id: "jira_readonly_conn",
          provider: :jira,
          profile: :api_token,
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
      write_actions =
        Enum.filter(spec.actions, &(&1.risk in [:write, :external_write, :destructive]))

      for action <- write_actions do
        assert availability[action.id].state == :missing_scopes
        assert length(availability[action.id].missing_scopes) > 0
      end
    end
  end

  defp all_jira_scopes(spec) do
    profile =
      Enum.find(spec.auth_profiles, &(&1.id == :api_token)) ||
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
