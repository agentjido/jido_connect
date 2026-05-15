defmodule Jido.Connect.Google.TasksTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Google.Tasks
  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  @readonly_scope "https://www.googleapis.com/auth/tasks.readonly"
  @write_scope "https://www.googleapis.com/auth/tasks"

  @task_list_action_modules [
    Jido.Connect.Google.Tasks.Actions.ListTaskLists,
    Jido.Connect.Google.Tasks.Actions.GetTaskList,
    Jido.Connect.Google.Tasks.Actions.CreateTaskList,
    Jido.Connect.Google.Tasks.Actions.UpdateTaskList,
    Jido.Connect.Google.Tasks.Actions.DeleteTaskList
  ]

  @task_list_dsl_fragments [
    Jido.Connect.Google.Tasks.Actions.TaskLists
  ]

  defmodule FakeTasksClient do
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
  end

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

    # Catalog packs are validated separately in catalog_packs_test.exs.
    # Pack allowed_tools include task IDs that will be registered in a later issue.

    assert Enum.map(spec.actions, & &1.id) == [
             "google.tasks.tasklist.list",
             "google.tasks.tasklist.get",
             "google.tasks.tasklist.create",
             "google.tasks.tasklist.update",
             "google.tasks.tasklist.delete"
           ]

    assert spec.triggers == []

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
      action_modules: @task_list_action_modules,
      plugin_module: Jido.Connect.Google.Tasks.Plugin,
      plugin_name: "google_tasks"
    )
  end

  test "loads Tasks Spark DSL fragments" do
    ConnectorContracts.assert_spark_fragments(@task_list_dsl_fragments)
  end

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
