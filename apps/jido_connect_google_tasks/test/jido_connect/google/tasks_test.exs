defmodule Jido.Connect.Google.TasksTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Google.Tasks
  alias Jido.Connect.Google.TestSupport.ConnectorContracts
  alias Jido.Connect.TriggerSpec

  @readonly_scope "https://www.googleapis.com/auth/tasks.readonly"
  @write_scope "https://www.googleapis.com/auth/tasks"

  @task_list_action_modules [
    Jido.Connect.Google.Tasks.Actions.ListTaskLists,
    Jido.Connect.Google.Tasks.Actions.GetTaskList,
    Jido.Connect.Google.Tasks.Actions.CreateTaskList,
    Jido.Connect.Google.Tasks.Actions.UpdateTaskList,
    Jido.Connect.Google.Tasks.Actions.DeleteTaskList
  ]

  @task_action_modules [
    Jido.Connect.Google.Tasks.Actions.ListTasks,
    Jido.Connect.Google.Tasks.Actions.GetTask,
    Jido.Connect.Google.Tasks.Actions.CreateTask,
    Jido.Connect.Google.Tasks.Actions.UpdateTask,
    Jido.Connect.Google.Tasks.Actions.DeleteTask,
    Jido.Connect.Google.Tasks.Actions.ClearTasks,
    Jido.Connect.Google.Tasks.Actions.MoveTask
  ]

  @all_action_modules @task_list_action_modules ++ @task_action_modules

  @task_list_dsl_fragments [
    Jido.Connect.Google.Tasks.Actions.TaskLists
  ]

  @task_dsl_fragments [
    Jido.Connect.Google.Tasks.Actions.Tasks
  ]

  @trigger_dsl_fragments [
    Jido.Connect.Google.Tasks.Triggers.Tasks
  ]

  @trigger_id "google.tasks.task.changed"
  @trigger_sensor Jido.Connect.Google.Tasks.Sensors.TaskChanged

  defmodule FakeTasksClient do
    # --- Task list fake methods ---

    def list_task_lists(%{page_size: 20}, "token") do
      {:ok,
       %{
         task_lists: [
           Tasks.TaskList.new!(%{
             task_list_id: "list_1",
             title: "My Tasks",
             updated: "2026-05-14T10:00:00.000Z"
           }),
           Tasks.TaskList.new!(%{
             task_list_id: "list_2",
             title: "Work"
           })
         ]
       }}
    end

    def list_task_lists(%{page_size: 1, page_token: "page_2"}, "token") do
      {:ok,
       %{
         task_lists: [
           Tasks.TaskList.new!(%{task_list_id: "list_2", title: "Work"})
         ]
       }}
    end

    def list_task_lists(%{page_size: 1} = params, "token")
        when not is_map_key(params, :page_token) do
      {:ok,
       %{
         task_lists: [
           Tasks.TaskList.new!(%{task_list_id: "list_1", title: "My Tasks"})
         ],
         next_page_token: "page_2"
       }}
    end

    def get_task_list(%{task_list_id: "list_1"}, "token") do
      {:ok,
       Tasks.TaskList.new!(%{
         task_list_id: "list_1",
         title: "My Tasks",
         updated: "2026-05-14T10:00:00.000Z",
         self_link: "https://www.googleapis.com/tasks/v1/users/@me/lists/list_1"
       })}
    end

    def create_task_list(%{title: "Personal"}, "token") do
      {:ok,
       Tasks.TaskList.new!(%{
         task_list_id: "list_new",
         title: "Personal",
         updated: "2026-05-15T12:00:00.000Z"
       })}
    end

    def update_task_list(
          %{task_list_id: "list_1", title: "Renamed Tasks"},
          "token"
        ) do
      {:ok,
       Tasks.TaskList.new!(%{
         task_list_id: "list_1",
         title: "Renamed Tasks",
         updated: "2026-05-15T13:00:00.000Z"
       })}
    end

    def delete_task_list(%{task_list_id: "list_2"}, "token") do
      {:ok, %{task_list_id: "list_2", deleted?: true}}
    end

    # --- Task fake methods ---

    def list_tasks(%{task_list_id: "list_1", page_size: 20}, "token") do
      {:ok,
       %{
         tasks: [
           Tasks.Task.new!(%{
             task_id: "task_1",
             task_list_id: "list_1",
             title: "Buy groceries",
             status: "needsAction"
           }),
           Tasks.Task.new!(%{
             task_id: "task_2",
             task_list_id: "list_1",
             title: "Write report",
             status: "completed"
           })
         ]
       }}
    end

    def list_tasks(%{task_list_id: "list_1", page_size: 1} = params, "token")
        when not is_map_key(params, :page_token) do
      {:ok,
       %{
         tasks: [
           Tasks.Task.new!(%{task_id: "task_1", title: "Buy groceries"})
         ],
         next_page_token: "task_page_2"
       }}
    end

    def list_tasks(%{task_list_id: "list_1", page_size: 1, page_token: "task_page_2"}, "token") do
      {:ok,
       %{
         tasks: [
           Tasks.Task.new!(%{task_id: "task_2", title: "Write report"})
         ]
       }}
    end

    def get_task(%{task_list_id: "list_1", task_id: "task_1"}, "token") do
      {:ok,
       Tasks.Task.new!(%{
         task_id: "task_1",
         task_list_id: "list_1",
         title: "Buy groceries",
         notes: "Milk, eggs, bread",
         status: "needsAction",
         due: "2026-05-20T00:00:00.000Z",
         self_link: "https://www.googleapis.com/tasks/v1/lists/list_1/tasks/task_1"
       })}
    end

    def create_task(%{task_list_id: "list_1", title: "New task"}, "token") do
      {:ok,
       Tasks.Task.new!(%{
         task_id: "task_new",
         task_list_id: "list_1",
         title: "New task",
         status: "needsAction",
         updated: "2026-05-15T14:00:00.000Z"
       })}
    end

    def update_task(%{task_list_id: "list_1", task_id: "task_1"}, "token") do
      {:ok,
       Tasks.Task.new!(%{
         task_id: "task_1",
         task_list_id: "list_1",
         title: "Updated groceries",
         status: "completed",
         updated: "2026-05-15T15:00:00.000Z"
       })}
    end

    def delete_task(%{task_list_id: "list_1", task_id: "task_2"}, "token") do
      {:ok, %{task_id: "task_2", task_list_id: "list_1", deleted?: true}}
    end

    def clear_tasks(%{task_list_id: "list_1"}, "token") do
      {:ok, %{task_list_id: "list_1", cleared?: true}}
    end

    def move_task(%{task_list_id: "list_1", task_id: "task_1"}, "token") do
      {:ok,
       Tasks.Task.new!(%{
         task_id: "task_1",
         task_list_id: "list_1",
         title: "Buy groceries",
         status: "needsAction",
         parent: "task_3",
         position: "00000000000000000001"
       })}
    end
  end

  # --- Provider metadata tests ---

  test "declares Google Tasks provider metadata" do
    spec = Tasks.integration()

    assert spec.id == :google_tasks
    assert spec.package == :jido_connect_google_tasks
    assert spec.name == "Google Tasks"
    assert spec.category == :productivity
    assert spec.status == :experimental
    assert spec.tags == [:google, :workspace, :tasks, :productivity]

    # Naming conventions for registered actions
    for action <- spec.actions do
      assert String.starts_with?(action.id, "google.tasks.")
      assert_present(action.label)
      assert action.scope_resolver
      assert action.data_classification
      assert action.risk
    end

    assert Enum.map(spec.actions, & &1.id) == [
             "google.tasks.tasklist.list",
             "google.tasks.tasklist.get",
             "google.tasks.tasklist.create",
             "google.tasks.tasklist.update",
             "google.tasks.tasklist.delete",
             "google.tasks.task.list",
             "google.tasks.task.get",
             "google.tasks.task.create",
             "google.tasks.task.update",
             "google.tasks.task.delete",
             "google.tasks.task.clear",
             "google.tasks.task.move"
           ]

    assert [%TriggerSpec{} = trigger] = spec.triggers
    assert trigger.id == @trigger_id
    assert trigger.kind == :poll
    assert trigger.checkpoint == :updated_min
    assert trigger.handler == Jido.Connect.Google.Tasks.Handlers.Triggers.TaskChangedPoller
    assert trigger.resource == :task
    assert trigger.verb == :watch
    assert trigger.data_classification == :workspace_metadata
    assert trigger.interval_ms == 300_000
    assert trigger.dedupe == %{key: [:task_id, :updated]}

    assert [%{id: :user, kind: :oauth2, refresh?: true, pkce?: true} = profile] =
             spec.auth_profiles

    assert "openid" in profile.default_scopes
    assert "email" in profile.default_scopes
    assert "profile" in profile.default_scopes
    assert @readonly_scope in profile.optional_scopes
    assert @write_scope in profile.optional_scopes
  end

  test "compiles generated Jido plugin surface" do
    ConnectorContracts.assert_generated_surface(Tasks,
      otp_app: :jido_connect_google_tasks,
      action_modules: @all_action_modules,
      sensor_specs: [
        %{
          module: @trigger_sensor,
          name: "google_tasks_task_changed",
          trigger_id: @trigger_id,
          signal_type: @trigger_id
        }
      ],
      plugin_module: Jido.Connect.Google.Tasks.Plugin,
      plugin_name: "google_tasks"
    )
  end

  test "loads Tasks Spark DSL fragments" do
    ConnectorContracts.assert_spark_fragments(
      @task_list_dsl_fragments ++ @task_dsl_fragments ++ @trigger_dsl_fragments
    )
  end

  # --- Task list invocation tests ---

  test "invokes list task lists through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              task_lists: [
                %{task_list_id: "list_1", title: "My Tasks"},
                %{task_list_id: "list_2", title: "Work"}
              ]
            }} =
             Connect.invoke(
               Tasks.integration(),
               "google.tasks.tasklist.list",
               %{},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes list task lists with pagination" do
    {context, lease} = context_and_lease()

    assert {:ok, %{task_lists: [%{task_list_id: "list_1"}], next_page_token: "page_2"}} =
             Connect.invoke(
               Tasks.integration(),
               "google.tasks.tasklist.list",
               %{page_size: 1},
               context: context,
               credential_lease: lease
             )

    assert {:ok, %{task_lists: [%{task_list_id: "list_2"}]}} =
             Connect.invoke(
               Tasks.integration(),
               "google.tasks.tasklist.list",
               %{page_size: 1, page_token: "page_2"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes get task list through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              task_list: %{
                task_list_id: "list_1",
                title: "My Tasks",
                self_link: "https://www.googleapis.com/tasks/v1/users/@me/lists/list_1"
              }
            }} =
             Connect.invoke(
               Tasks.integration(),
               "google.tasks.tasklist.get",
               %{task_list_id: " list_1 "},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes create task list through injected client and lease" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:ok, %{task_list: %{task_list_id: "list_new", title: "Personal"}}} =
             Connect.invoke(
               Tasks.integration(),
               "google.tasks.tasklist.create",
               %{title: " Personal "},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes update task list through injected client and lease" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:ok, %{task_list: %{task_list_id: "list_1", title: "Renamed Tasks"}}} =
             Connect.invoke(
               Tasks.integration(),
               "google.tasks.tasklist.update",
               %{task_list_id: " list_1 ", title: " Renamed Tasks "},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes delete task list through injected client and lease" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:ok, %{result: %{task_list_id: "list_2", deleted?: true}}} =
             Connect.invoke(
               Tasks.integration(),
               "google.tasks.tasklist.delete",
               %{task_list_id: " list_2 "},
               context: context,
               credential_lease: lease
             )
  end

  # --- Task invocation tests ---

  test "invokes list tasks through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              tasks: [
                %{task_id: "task_1", title: "Buy groceries"},
                %{task_id: "task_2", title: "Write report"}
              ]
            }} =
             Connect.invoke(
               Tasks.integration(),
               "google.tasks.task.list",
               %{task_list_id: " list_1 "},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes list tasks with pagination" do
    {context, lease} = context_and_lease()

    assert {:ok, %{tasks: [%{task_id: "task_1"}], next_page_token: "task_page_2"}} =
             Connect.invoke(
               Tasks.integration(),
               "google.tasks.task.list",
               %{task_list_id: "list_1", page_size: 1},
               context: context,
               credential_lease: lease
             )

    assert {:ok, %{tasks: [%{task_id: "task_2"}]}} =
             Connect.invoke(
               Tasks.integration(),
               "google.tasks.task.list",
               %{task_list_id: "list_1", page_size: 1, page_token: "task_page_2"},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes get task through injected client and lease" do
    {context, lease} = context_and_lease()

    assert {:ok,
            %{
              task: %{
                task_id: "task_1",
                title: "Buy groceries",
                notes: "Milk, eggs, bread",
                status: "needsAction",
                due: "2026-05-20T00:00:00.000Z"
              }
            }} =
             Connect.invoke(
               Tasks.integration(),
               "google.tasks.task.get",
               %{task_list_id: " list_1 ", task_id: " task_1 "},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes create task through injected client and lease" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:ok, %{task: %{task_id: "task_new", title: "New task"}}} =
             Connect.invoke(
               Tasks.integration(),
               "google.tasks.task.create",
               %{task_list_id: " list_1 ", title: " New task "},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes update task through injected client and lease" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:ok, %{task: %{task_id: "task_1", title: "Updated groceries"}}} =
             Connect.invoke(
               Tasks.integration(),
               "google.tasks.task.update",
               %{task_list_id: " list_1 ", task_id: " task_1 "},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes delete task through injected client and lease" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:ok, %{result: %{task_id: "task_2", task_list_id: "list_1", deleted?: true}}} =
             Connect.invoke(
               Tasks.integration(),
               "google.tasks.task.delete",
               %{task_list_id: " list_1 ", task_id: " task_2 "},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes clear tasks through injected client and lease" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:ok, %{result: %{task_list_id: "list_1", cleared?: true}}} =
             Connect.invoke(
               Tasks.integration(),
               "google.tasks.task.clear",
               %{task_list_id: " list_1 "},
               context: context,
               credential_lease: lease
             )
  end

  test "invokes move task through injected client and lease" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:ok, %{task: %{task_id: "task_1", parent: "task_3"}}} =
             Connect.invoke(
               Tasks.integration(),
               "google.tasks.task.move",
               %{task_list_id: " list_1 ", task_id: " task_1 "},
               context: context,
               credential_lease: lease
             )
  end

  # --- Scope enforcement tests ---

  test "write actions require Tasks write scope" do
    {context, lease} = context_and_lease()

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: [@write_scope]
            }} =
             Connect.invoke(
               Tasks.integration(),
               "google.tasks.tasklist.create",
               %{title: "Personal"},
               context: context,
               credential_lease: lease
             )
  end

  test "task write actions require Tasks write scope" do
    {context, lease} = context_and_lease()

    assert {:error,
            %Connect.Error.AuthError{
              reason: :missing_scopes,
              missing_scopes: [@write_scope]
            }} =
             Connect.invoke(
               Tasks.integration(),
               "google.tasks.task.create",
               %{task_list_id: "list_1", title: "New task"},
               context: context,
               credential_lease: lease
             )
  end

  # --- Task list validation tests ---

  test "get task list validates required task_list_id" do
    {context, lease} = context_and_lease()

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_task_list_request,
              details: %{field: :task_list_id}
            }} =
             Connect.invoke(
               Tasks.integration(),
               "google.tasks.tasklist.get",
               %{task_list_id: " "},
               context: context,
               credential_lease: lease
             )
  end

  test "create task list validates required title" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_task_list_request,
              details: %{field: :title}
            }} =
             Connect.invoke(
               Tasks.integration(),
               "google.tasks.tasklist.create",
               %{title: " "},
               context: context,
               credential_lease: lease
             )
  end

  test "update task list validates required fields" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:error, %Connect.Error.ValidationError{reason: :input}} =
             Connect.invoke(
               Tasks.integration(),
               "google.tasks.tasklist.update",
               %{title: "Updated"},
               context: context,
               credential_lease: lease
             )

    assert {:error, %Connect.Error.ValidationError{reason: :input}} =
             Connect.invoke(
               Tasks.integration(),
               "google.tasks.tasklist.update",
               %{task_list_id: "list_1"},
               context: context,
               credential_lease: lease
             )
  end

  test "delete task list validates required task_list_id" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_task_list_request,
              details: %{field: :task_list_id}
            }} =
             Connect.invoke(
               Tasks.integration(),
               "google.tasks.tasklist.delete",
               %{task_list_id: " "},
               context: context,
               credential_lease: lease
             )
  end

  # --- Task validation tests ---

  test "list tasks validates required task_list_id" do
    {context, lease} = context_and_lease()

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_task_request,
              details: %{field: :task_list_id}
            }} =
             Connect.invoke(
               Tasks.integration(),
               "google.tasks.task.list",
               %{task_list_id: " "},
               context: context,
               credential_lease: lease
             )
  end

  test "get task validates required task_list_id and task_id" do
    {context, lease} = context_and_lease()

    assert {:error, %Connect.Error.ValidationError{reason: :input}} =
             Connect.invoke(
               Tasks.integration(),
               "google.tasks.task.get",
               %{task_id: "task_1"},
               context: context,
               credential_lease: lease
             )

    assert {:error, %Connect.Error.ValidationError{reason: :input}} =
             Connect.invoke(
               Tasks.integration(),
               "google.tasks.task.get",
               %{task_list_id: "list_1"},
               context: context,
               credential_lease: lease
             )
  end

  test "get task validates non-blank task_list_id" do
    {context, lease} = context_and_lease()

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_task_request,
              details: %{field: :task_list_id}
            }} =
             Connect.invoke(
               Tasks.integration(),
               "google.tasks.task.get",
               %{task_list_id: " ", task_id: "task_1"},
               context: context,
               credential_lease: lease
             )
  end

  test "get task validates non-blank task_id" do
    {context, lease} = context_and_lease()

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_task_request,
              details: %{field: :task_id}
            }} =
             Connect.invoke(
               Tasks.integration(),
               "google.tasks.task.get",
               %{task_list_id: "list_1", task_id: " "},
               context: context,
               credential_lease: lease
             )
  end

  test "create task validates required task_list_id and title" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:error, %Connect.Error.ValidationError{reason: :input}} =
             Connect.invoke(
               Tasks.integration(),
               "google.tasks.task.create",
               %{title: "New task"},
               context: context,
               credential_lease: lease
             )

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_task_request,
              details: %{field: :title}
            }} =
             Connect.invoke(
               Tasks.integration(),
               "google.tasks.task.create",
               %{task_list_id: "list_1", title: " "},
               context: context,
               credential_lease: lease
             )
  end

  test "update task validates required task_list_id and task_id" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:error, %Connect.Error.ValidationError{reason: :input}} =
             Connect.invoke(
               Tasks.integration(),
               "google.tasks.task.update",
               %{task_id: "task_1"},
               context: context,
               credential_lease: lease
             )

    assert {:error, %Connect.Error.ValidationError{reason: :input}} =
             Connect.invoke(
               Tasks.integration(),
               "google.tasks.task.update",
               %{task_list_id: "list_1"},
               context: context,
               credential_lease: lease
             )
  end

  test "delete task validates required task_list_id and task_id" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:error, %Connect.Error.ValidationError{reason: :input}} =
             Connect.invoke(
               Tasks.integration(),
               "google.tasks.task.delete",
               %{task_id: "task_1"},
               context: context,
               credential_lease: lease
             )

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_task_request,
              details: %{field: :task_id}
            }} =
             Connect.invoke(
               Tasks.integration(),
               "google.tasks.task.delete",
               %{task_list_id: "list_1", task_id: " "},
               context: context,
               credential_lease: lease
             )
  end

  test "clear tasks validates required task_list_id" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_task_request,
              details: %{field: :task_list_id}
            }} =
             Connect.invoke(
               Tasks.integration(),
               "google.tasks.task.clear",
               %{task_list_id: " "},
               context: context,
               credential_lease: lease
             )
  end

  test "move task validates required task_list_id and task_id" do
    {context, lease} = context_and_lease(scopes: write_scopes())

    assert {:error, %Connect.Error.ValidationError{reason: :input}} =
             Connect.invoke(
               Tasks.integration(),
               "google.tasks.task.move",
               %{task_id: "task_1"},
               context: context,
               credential_lease: lease
             )

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_task_request,
              details: %{field: :task_id}
            }} =
             Connect.invoke(
               Tasks.integration(),
               "google.tasks.task.move",
               %{task_list_id: "list_1", task_id: " "},
               context: context,
               credential_lease: lease
             )
  end

  # --- Helpers ---

  defp context_and_lease(opts \\ []) do
    scopes = Keyword.get(opts, :scopes, read_scopes())

    connection =
      Connect.Connection.new!(%{
        id: "conn_1",
        provider: :google_tasks,
        profile: :user,
        tenant_id: "tenant_1",
        owner_type: :app_user,
        owner_id: "user_1",
        status: :connected,
        scopes: scopes
      })

    context =
      Connect.Context.new!(%{
        tenant_id: "tenant_1",
        actor: %{id: "user_1", type: :user},
        connection: connection
      })

    lease =
      Connect.CredentialLease.new!(%{
        connection_id: "conn_1",
        provider: :google_tasks,
        profile: :user,
        expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
        fields: %{access_token: "token", google_tasks_client: FakeTasksClient},
        scopes: scopes
      })

    {context, lease}
  end

  defp assert_present(value) when is_binary(value), do: assert(String.trim(value) != "")
  defp assert_present(_), do: flunk("expected non-empty string")

  defp read_scopes do
    ["openid", "email", "profile", @readonly_scope]
  end

  defp write_scopes do
    ["openid", "email", "profile", @write_scope]
  end
end
