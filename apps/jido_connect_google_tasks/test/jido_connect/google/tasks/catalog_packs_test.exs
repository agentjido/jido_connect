defmodule Jido.Connect.Google.Tasks.CatalogPacksTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Catalog
  alias Jido.Connect.Google.Tasks

  @readonly_tools [
    "google.tasks.tasklist.list",
    "google.tasks.tasklist.get",
    "google.tasks.task.list",
    "google.tasks.task.get",
    "google.tasks.task.changed"
  ]

  @editor_tools @readonly_tools ++
                  [
                    "google.tasks.tasklist.create",
                    "google.tasks.tasklist.update",
                    "google.tasks.tasklist.delete",
                    "google.tasks.task.create",
                    "google.tasks.task.update",
                    "google.tasks.task.delete",
                    "google.tasks.task.clear",
                    "google.tasks.task.move"
                  ]

  defmodule FakeTasksClient do
    def create_task_list(%{title: "Personal"}, "token") do
      {:ok,
       Tasks.TaskList.new!(%{
         task_list_id: "list_new",
         title: "Personal",
         updated: "2026-05-15T12:00:00.000Z"
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
  end

  # --- Pack structure tests ---

  test "readonly pack contains only read tools" do
    packs = Tasks.catalog_packs()
    readonly = Enum.find(packs, &(&1.id == :google_tasks_readonly))

    assert readonly.allowed_tools == @readonly_tools
    assert readonly.metadata.risk == :read
    assert readonly.filters == %{provider: :google_tasks}
  end

  test "editor pack contains all tools" do
    packs = Tasks.catalog_packs()
    editor = Enum.find(packs, &(&1.id == :google_tasks_editor))

    assert editor.allowed_tools == @editor_tools
    assert editor.metadata.risk == :write
    assert editor.filters == %{provider: :google_tasks}
  end

  test "pack delegates return expected packs" do
    assert %{id: :google_tasks_readonly} = Tasks.readonly_pack()
    assert %{id: :google_tasks_editor} = Tasks.editor_pack()

    assert Enum.map(Tasks.catalog_packs(), & &1.id) ==
             [:google_tasks_readonly, :google_tasks_editor]
  end

  test "editor tools are a superset of readonly tools" do
    packs = Tasks.catalog_packs()
    readonly = Enum.find(packs, &(&1.id == :google_tasks_readonly))
    editor = Enum.find(packs, &(&1.id == :google_tasks_editor))

    readonly_set = MapSet.new(readonly.allowed_tools)
    editor_set = MapSet.new(editor.allowed_tools)

    assert MapSet.subset?(readonly_set, editor_set)
    assert MapSet.difference(editor_set, readonly_set) |> MapSet.size() > 0
  end

  # --- Catalog search integration tests ---

  test "readonly pack restricts search and describe to read tools" do
    results =
      Catalog.search_tools("tasks",
        modules: [Tasks],
        packs: Tasks.catalog_packs(),
        pack: :google_tasks_readonly
      )

    ids = Enum.map(results, & &1.tool.id)

    assert "google.tasks.tasklist.list" in ids
    assert "google.tasks.tasklist.get" in ids
    assert "google.tasks.task.list" in ids
    assert "google.tasks.task.get" in ids
    assert "google.tasks.task.changed" in ids
    refute "google.tasks.tasklist.create" in ids
    refute "google.tasks.task.create" in ids
    refute "google.tasks.task.delete" in ids
    refute "google.tasks.task.move" in ids

    assert {:ok, descriptor} =
             Catalog.describe_tool("google.tasks.task.get",
               modules: [Tasks],
               packs: Tasks.catalog_packs(),
               pack: :google_tasks_readonly
             )

    assert descriptor.tool.id == "google.tasks.task.get"

    assert {:ok, trigger_descriptor} =
             Catalog.describe_tool("google.tasks.task.changed",
               modules: [Tasks],
               packs: Tasks.catalog_packs(),
               pack: :google_tasks_readonly
             )

    assert trigger_descriptor.tool.id == "google.tasks.task.changed"

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.describe_tool("google.tasks.task.create",
               modules: [Tasks],
               packs: Tasks.catalog_packs(),
               pack: :google_tasks_readonly
             )
  end

  test "editor pack allows all read and write tools" do
    assert {:ok, descriptor} =
             Catalog.describe_tool("google.tasks.task.create",
               modules: [Tasks],
               packs: Tasks.catalog_packs(),
               pack: :google_tasks_editor
             )

    assert descriptor.tool.id == "google.tasks.task.create"

    assert {:ok, descriptor} =
             Catalog.describe_tool("google.tasks.tasklist.delete",
               modules: [Tasks],
               packs: Tasks.catalog_packs(),
               pack: :google_tasks_editor
             )

    assert descriptor.tool.id == "google.tasks.tasklist.delete"

    assert {:ok, descriptor} =
             Catalog.describe_tool("google.tasks.task.move",
               modules: [Tasks],
               packs: Tasks.catalog_packs(),
               pack: :google_tasks_editor
             )

    assert descriptor.tool.id == "google.tasks.task.move"

    assert {:ok, trigger_descriptor} =
             Catalog.describe_tool("google.tasks.task.changed",
               modules: [Tasks],
               packs: Tasks.catalog_packs(),
               pack: :google_tasks_editor
             )

    assert trigger_descriptor.tool.id == "google.tasks.task.changed"
  end

  # --- Catalog call_tool enforcement tests ---

  test "pack restrictions apply to call_tool" do
    {context, lease} = context_and_lease()

    assert {:ok, %{task_list: %{task_list_id: "list_new"}}} =
             Catalog.call_tool(
               "google.tasks.tasklist.create",
               %{title: "Personal"},
               modules: [Tasks],
               packs: Tasks.catalog_packs(),
               pack: :google_tasks_editor,
               context: context,
               credential_lease: lease
             )

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.call_tool(
               "google.tasks.tasklist.create",
               %{title: "Personal"},
               modules: [Tasks],
               packs: Tasks.catalog_packs(),
               pack: :google_tasks_readonly,
               context: context,
               credential_lease: lease
             )
  end

  test "editor pack allows task mutation call_tool" do
    {context, lease} = context_and_lease()

    assert {:ok, %{task: %{task_id: "task_new"}}} =
             Catalog.call_tool(
               "google.tasks.task.create",
               %{task_list_id: "list_1", title: "New task"},
               modules: [Tasks],
               packs: Tasks.catalog_packs(),
               pack: :google_tasks_editor,
               context: context,
               credential_lease: lease
             )

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.call_tool(
               "google.tasks.task.create",
               %{task_list_id: "list_1", title: "New task"},
               modules: [Tasks],
               packs: Tasks.catalog_packs(),
               pack: :google_tasks_readonly,
               context: context,
               credential_lease: lease
             )
  end

  # --- Helpers ---

  defp context_and_lease do
    scopes = [
      "openid",
      "email",
      "profile",
      "https://www.googleapis.com/auth/tasks"
    ]

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
end
