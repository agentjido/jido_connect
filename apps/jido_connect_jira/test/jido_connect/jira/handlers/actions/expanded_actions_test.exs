defmodule Jido.Connect.Jira.Handlers.Actions.ExpandedActionsTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Error
  alias Jido.Connect.Jira.Actions, as: GeneratedActions
  alias Jido.Connect.Jira.Input.{Boards, Filters, Plans}
  alias Jido.Connect.Jira.TestRuntime
  alias Jido.Connect.Jira.Handlers.Actions

  defmodule Client do
    alias Jido.Connect.Error
    alias Jido.Connect.Jira.Client.Request

    def list_boards(%Request{}, opts),
      do: result(:list_boards, opts, %{boards: [], total: 0, offset: 0, limit: 50, is_last: true})

    def get_board(84, %Request{}), do: result(:get_board, 84, %{id: "84", name: "Docket"})

    def get_board(404, %Request{}),
      do: {:error, Error.provider("missing", provider: :jira, status: 404)}

    def create_board(attrs, %Request{}),
      do: result(:create_board, attrs, %{id: "84", name: attrs.name})

    def list_filters(%Request{}, opts),
      do:
        result(:list_filters, opts, %{filters: [], total: 0, offset: 0, limit: 50, is_last: true})

    def get_filter(10_000, %Request{}),
      do: result(:get_filter, 10_000, %{id: "10000", name: "Docket"})

    def create_filter(attrs, %Request{}),
      do: result(:create_filter, attrs, %{id: "10000", name: attrs.name})

    def update_filter(10_000, attrs, %Request{}),
      do: result(:update_filter, attrs, %{id: "10000", name: attrs.name})

    def get_filter_columns(10_000, %Request{}),
      do: result(:get_filter_columns, 10_000, %{filter_id: "10000", columns: []})

    def update_filter_columns(10_000, columns, %Request{}),
      do:
        result(:update_filter_columns, columns, %{filter_id: "10000", columns: [], updated: true})

    def replace_filter_shares(10_000, attrs, %Request{}),
      do:
        result(:replace_filter_shares, attrs, %{
          filter_id: "10000",
          scope: attrs.scope,
          permissions: [],
          updated: true
        })

    def list_issue_transitions("PROJ-1", %Request{}),
      do:
        result(:list_issue_transitions, "PROJ-1", %{
          issue_key: "PROJ-1",
          transitions: [],
          count: 0
        })

    def delete_issue("PROJ-1", %Request{}),
      do: result(:delete_issue, "PROJ-1", %{issue_key: "PROJ-1", deleted: true})

    def list_plans(%Request{}, opts),
      do:
        result(:list_plans, opts, %{
          plans: [],
          total: 0,
          limit: 50,
          next_cursor: nil,
          is_last: true
        })

    def get_plan(1237, %Request{}), do: result(:get_plan, 1237, %{id: "1237", name: "Plan"})

    def create_plan(attrs, %Request{}),
      do: result(:create_plan, attrs, %{id: "1237", name: attrs.name, created: true})

    def update_plan(1237, attrs, %Request{}),
      do: result(:update_plan, attrs, %{id: "1237", updated: true, changed_fields: ["name"]})

    def duplicate_plan(1237, name, %Request{}),
      do:
        result(:duplicate_plan, name, %{
          id: "1238",
          source_plan_id: "1237",
          name: name,
          duplicated: true
        })

    def archive_plan(1237, %Request{}),
      do: result(:archive_plan, 1237, %{id: "1237", updated: true})

    def trash_plan(1237, %Request{}), do: result(:trash_plan, 1237, %{id: "1237", updated: true})

    defp result(operation, input, output) do
      send(self(), {:jira_expanded_client, operation, input})
      {:ok, output}
    end
  end

  setup do
    %{runtime: TestRuntime.build(provider_client: Client)}
  end

  test "board, filter, issue, and plan handlers delegate normalized inputs", %{runtime: runtime} do
    cases = [
      {Actions.ListBoards, %{limit: 20, offset: 5}, :list_boards},
      {Actions.GetBoard, %{id: 84}, :get_board},
      {Actions.CreateBoard,
       %{name: "Docket", type: "kanban", filter_id: 10_000, location: "project", project: "DOC"},
       :create_board},
      {Actions.ListFilters, %{limit: 20, offset: 0}, :list_filters},
      {Actions.GetFilter, %{id: 10_000}, :get_filter},
      {Actions.CreateFilter, %{name: "Docket", query: "project = DOC", favorite: false},
       :create_filter},
      {Actions.UpdateFilter, %{id: 10_000, name: "Docket", query: "project = DOC"},
       :update_filter},
      {Actions.GetFilterColumns, %{id: 10_000}, :get_filter_columns},
      {Actions.UpdateFilterColumns, %{id: 10_000, columns: ["issuekey"]}, :update_filter_columns},
      {Actions.UpdateFilterShare, %{id: 10_000, scope: "private"}, :replace_filter_shares},
      {Actions.ListIssueTransitions, %{issue_key: "PROJ-1"}, :list_issue_transitions},
      {Actions.DeleteIssue, %{issue_key: "PROJ-1"}, :delete_issue},
      {Actions.ListPlans, %{limit: 20}, :list_plans},
      {Actions.GetPlan, %{id: 1237}, :get_plan},
      {Actions.CreatePlan, valid_plan(), :create_plan},
      {Actions.UpdatePlan, %{id: 1237, name: "Renamed"}, :update_plan},
      {Actions.DuplicatePlan, %{id: 1237, name: "Copy"}, :duplicate_plan},
      {Actions.ArchivePlan, %{id: 1237}, :archive_plan},
      {Actions.TrashPlan, %{id: 1237}, :trash_plan}
    ]

    for {module, input, operation} <- cases do
      assert {:ok, _result} = module.run(input, runtime)
      assert_received {:jira_expanded_client, ^operation, _input}
    end
  end

  test "generated Jido actions expose metadata and require runtime context" do
    cases = [
      {GeneratedActions.ListBoards, %{limit: 20, offset: 5}},
      {GeneratedActions.GetBoard, %{id: 84}},
      {GeneratedActions.CreateBoard,
       %{
         name: "Docket",
         type: "kanban",
         filter_id: 10_000,
         location: "project",
         project: "DOC"
       }},
      {GeneratedActions.ListFilters, %{limit: 20, offset: 0}},
      {GeneratedActions.GetFilter, %{id: 10_000}},
      {GeneratedActions.CreateFilter, %{name: "Docket", query: "project = DOC", favorite: false}},
      {GeneratedActions.UpdateFilter, %{id: 10_000, name: "Docket", query: "project = DOC"}},
      {GeneratedActions.GetFilterColumns, %{id: 10_000}},
      {GeneratedActions.UpdateFilterColumns, %{id: 10_000, columns: ["issuekey"]}},
      {GeneratedActions.UpdateFilterShare, %{id: 10_000, scope: "private"}},
      {GeneratedActions.ListIssueTransitions, %{issue_key: "PROJ-1"}},
      {GeneratedActions.DeleteIssue, %{issue_key: "PROJ-1"}},
      {GeneratedActions.ListPlans, %{limit: 20}},
      {GeneratedActions.GetPlan, %{id: 1237}},
      {GeneratedActions.CreatePlan, valid_plan()},
      {GeneratedActions.UpdatePlan, %{id: 1237, name: "Renamed"}},
      {GeneratedActions.DuplicatePlan, %{id: 1237, name: "Copy"}},
      {GeneratedActions.ArchivePlan, %{id: 1237}},
      {GeneratedActions.TrashPlan, %{id: 1237}}
    ]

    for {module, input} <- cases do
      assert {:error, %Error.AuthError{reason: :context_required}} = module.run(input, %{})
      assert module.operation_id() == module.jido_connect_projection().action_id
    end
  end

  test "handlers preserve normalized auth and provider errors", %{runtime: runtime} do
    assert {:error, %Error.ProviderError{status: 404}} = Actions.GetBoard.run(%{id: 404}, runtime)

    insecure = TestRuntime.build(provider_client: Client, site: "http://jira.example.test")

    assert {:error, %Error.AuthError{reason: :insecure_jira_endpoint}} =
             Actions.GetBoard.run(%{id: 84}, insecure)
  end

  test "validates cross-field and nested plan contracts before provider calls" do
    assert {:error, %Error.ValidationError{reason: :invalid_jira_input}} =
             Boards.create(%{
               name: "Board",
               type: "kanban",
               filter_id: 1,
               location: "user",
               project: "DOC"
             })

    assert {:error, %Error.ValidationError{reason: :invalid_jira_input}} =
             Boards.create(%{
               name: "Board",
               type: "kanban",
               filter_id: 1,
               location: "project"
             })

    assert {:error, %Error.ValidationError{reason: :invalid_jira_input}} =
             Filters.columns(%{id: 1, columns: ["issuekey", "issuekey"]})

    assert {:error, %Error.ValidationError{reason: :invalid_jira_input}} =
             Filters.columns(%{id: 1, columns: []})

    assert {:error, %Error.ValidationError{reason: :invalid_jira_input}} =
             Filters.share(%{id: 1, scope: "projects", projects: []})

    assert {:error, %Error.ValidationError{reason: :invalid_jira_input}} =
             Filters.share(%{id: 1, scope: "private", projects: ["DOC"]})

    assert {:ok, _input} =
             Filters.share(%{id: 1, scope: "groups", group_ids: ["group-1"]})

    assert {:error, %Error.ValidationError{reason: :invalid_jira_input}} =
             Plans.create(%{
               name: "Plan",
               issue_sources: [%{type: "Unknown", value: 1}],
               scheduling: %{estimation: "Days"}
             })

    assert {:error, %Error.ValidationError{reason: :invalid_jira_input}} =
             Plans.create(%{
               name: "Plan",
               issue_sources: [],
               scheduling: %{estimation: "Days"}
             })

    assert {:error, %Error.ValidationError{reason: :invalid_jira_input}} =
             Plans.create(%{
               name: "Plan",
               issue_sources: [%{type: "Project", value: 1}],
               scheduling: %{
                 estimation: "Days",
                 startDate: %{type: "DateCustomField"}
               }
             })

    assert {:error, %Error.ValidationError{reason: :invalid_jira_input}} =
             Plans.create(%{
               name: "Plan",
               issue_sources: [%{type: "Project", value: 1}],
               scheduling: %{
                 estimation: "Days",
                 startDate: %{type: "DateCustomField", dateCustomFieldId: 2_147_483_648}
               }
             })

    assert {:error, %Error.ValidationError{reason: :invalid_jira_input}} =
             Plans.create(%{
               name: "Plan",
               issue_sources: [%{type: "Project", value: 1}],
               scheduling: %{
                 estimation: "Days",
                 startDate: %{type: "DueDate", dateCustomFieldId: 1}
               }
             })

    assert {:error, %Error.ValidationError{reason: :invalid_jira_input}} =
             Plans.create(%{
               name: "Plan",
               issue_sources: [%{type: "Project", value: 1, extra: true}],
               scheduling: %{estimation: "Days"}
             })

    assert {:error, %Error.ValidationError{reason: :invalid_jira_input}} =
             Plans.update(%{id: 1237})

    assert {:error, %Error.ValidationError{reason: :invalid_jira_input}} =
             Plans.update(%{id: 1237, exclusion_rules: %{}})

    assert {:error, %Error.ValidationError{reason: :invalid_jira_input}} =
             Plans.create(%{
               name: "Plan",
               issue_sources: [%{type: "Project", value: 2_147_483_648}],
               scheduling: %{estimation: "Days"}
             })

    assert {:error, %Error.ValidationError{reason: :invalid_jira_input}} =
             Plans.create(%{
               name: "Plan",
               issue_sources: [
                 %{type: "Project", value: 1},
                 %{type: "Project", value: 1}
               ],
               scheduling: %{estimation: "Days"}
             })

    assert {:error, %Error.ValidationError{reason: :invalid_jira_input}} =
             Plans.create(%{
               name: "Plan",
               issue_sources: [%{type: "Project", value: 1}],
               scheduling: %{estimation: "Days"},
               cross_project_releases: [
                 %{name: String.duplicate("x", 256), releaseIds: [1]}
               ]
             })

    assert {:error, %Error.ValidationError{reason: :invalid_jira_input}} =
             Plans.create(%{
               name: "Plan",
               issue_sources: [%{type: "Project", value: 1}],
               scheduling: %{estimation: "Days"},
               permissions: [
                 %{
                   type: "View",
                   holder: %{type: "AccountId", value: String.duplicate("x", 256)}
                 }
               ]
             })

    assert {:error, %Error.ValidationError{reason: :invalid_jira_input}} =
             Plans.create(%{
               name: "Plan",
               issue_sources: [%{type: "Project", value: 1}],
               scheduling: %{estimation: "Days"},
               custom_fields: String.duplicate("x", 101) |> String.graphemes()
             })

    assert {:ok, normalized} = Plans.create(valid_plan())
    assert normalized.issue_sources == [%{type: "Project", value: 10_000}]
    assert normalized.scheduling.startDate == %{type: "TargetStartDate"}

    assert {:ok, update} =
             Plans.update(%{
               id: 1237,
               issue_sources: [%{type: "Filter", value: 10_000}],
               scheduling: %{
                 startDate: %{type: "DateCustomField", dateCustomFieldId: 10_001},
                 inferredDates: "SprintDates"
               },
               exclusion_rules: %{
                 numberOfDaysToShowCompletedIssues: 30,
                 issueIds: [1],
                 workStatusIds: [2],
                 workStatusCategoryIds: [3],
                 issueTypeIds: [4],
                 releaseIds: [5]
               },
               cross_project_releases: [%{name: "Release", releaseIds: [5]}],
               custom_fields: [%{customFieldId: 10_001, filter: true}],
               permissions: [
                 %{type: "View", holder: %{type: "Group", value: "group-1"}}
               ]
             })

    assert update.scheduling.startDate.dateCustomFieldId == 10_001
  end

  test "all expanded write previews contain safe summaries" do
    cases = [
      {Jido.Connect.Jira.Previews.CreateBoard,
       %{name: "Docket", type: "kanban", filter_id: 1, location: "user"}},
      {Jido.Connect.Jira.Previews.CreateFilter, %{name: "Filter", query: "secret project = DOC"}},
      {Jido.Connect.Jira.Previews.UpdateFilter,
       %{id: 1, name: "Filter", query: "secret project = DOC"}},
      {Jido.Connect.Jira.Previews.UpdateFilterColumns, %{id: 1, columns: ["issuekey"]}},
      {Jido.Connect.Jira.Previews.UpdateFilterShare, %{id: 1, scope: "private"}},
      {Jido.Connect.Jira.Previews.DeleteIssue, %{issue_key: "PROJ-1"}},
      {Jido.Connect.Jira.Previews.CreatePlan, valid_plan()},
      {Jido.Connect.Jira.Previews.UpdatePlan, %{id: 1237, name: "Renamed"}},
      {Jido.Connect.Jira.Previews.DuplicatePlan, %{id: 1237, name: "Copy"}},
      {Jido.Connect.Jira.Previews.ArchivePlan, %{id: 1237}},
      {Jido.Connect.Jira.Previews.TrashPlan, %{id: 1237}}
    ]

    for {module, input} <- cases do
      preview = module.preview(input, %{})
      assert is_binary(preview.operation)
      refute inspect(preview) =~ "secret project"
    end
  end

  defp valid_plan do
    %{
      name: "Plan",
      issue_sources: [%{type: "Project", value: 10_000}],
      scheduling: %{
        estimation: "Days",
        startDate: %{type: "TargetStartDate"},
        dependencies: "Sequential"
      }
    }
  end
end
