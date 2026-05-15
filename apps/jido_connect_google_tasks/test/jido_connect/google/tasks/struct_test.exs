defmodule Jido.Connect.Google.Tasks.StructTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Tasks.{Link, MutationResult, Task, TaskList}
  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  # --- TaskList ---

  test "task list struct validates with Zoi" do
    task_list =
      ConnectorContracts.assert_struct_defaults(
        TaskList,
        %{task_list_id: "MDAxNjUwMjY0MzQ1NjM0NzY3Mjo3Njc0MzI2NDpx"},
        metadata: %{}
      )

    assert task_list.task_list_id == "MDAxNjUwMjY0MzQ1NjM0NzY3Mjo3Njc0MzI2NDpx"
  end

  test "task list struct accepts full attributes" do
    task_list =
      TaskList.new!(%{
        task_list_id: "list_abc",
        etag: "\"etag123\"",
        title: "Work Tasks",
        updated: "2026-05-10T12:00:00.000Z",
        self_link: "https://www.googleapis.com/tasks/v1/users/@me/lists/list_abc"
      })

    assert task_list.title == "Work Tasks"
    assert task_list.etag == "\"etag123\""
    assert task_list.updated == "2026-05-10T12:00:00.000Z"
    assert task_list.self_link == "https://www.googleapis.com/tasks/v1/users/@me/lists/list_abc"
  end

  test "task list struct rejects missing task_list_id" do
    assert {:error, _error} = TaskList.new(%{})
  end

  # --- Link ---

  test "link struct validates with Zoi" do
    link =
      ConnectorContracts.assert_struct_defaults(
        Link,
        %{type: "text/html", description: "Related", link: "https://example.com"},
        metadata: %{}
      )

    assert link.type == "text/html"
    assert link.description == "Related"
    assert link.link == "https://example.com"
  end

  test "link struct accepts empty optional fields" do
    link = Link.new!(%{})
    assert link.metadata == %{}
  end

  test "link struct accepts partial attributes" do
    link = Link.new!(%{link: "https://example.com/resource"})
    assert link.link == "https://example.com/resource"
    assert link.type == nil
    assert link.description == nil
  end

  # --- Task ---

  test "task struct validates with Zoi" do
    task =
      ConnectorContracts.assert_struct_defaults(
        Task,
        %{task_id: "task_abc123"},
        metadata: %{},
        links: [],
        deleted?: false,
        hidden?: false
      )

    assert task.task_id == "task_abc123"
  end

  test "task struct accepts full attributes" do
    task =
      Task.new!(%{
        task_id: "task_abc123",
        task_list_id: "list_xyz",
        etag: "\"etag456\"",
        title: "Write report",
        updated: "2026-05-12T09:30:00.000Z",
        self_link: "https://www.googleapis.com/tasks/v1/lists/list_xyz/tasks/task_abc123",
        parent: "",
        position: "00000000000000000000",
        notes: "Quarterly financial report.",
        status: "needsAction",
        due: "2026-05-20T00:00:00.000Z",
        completed: "",
        deleted?: false,
        hidden?: false,
        links: [
          %{type: "text/html", description: "Template", link: "https://example.com/template"}
        ],
        web_view_link: "https://tasks.google.com/task/task_abc123"
      })

    assert task.title == "Write report"
    assert task.task_list_id == "list_xyz"
    assert task.status == "needsAction"
    assert task.due == "2026-05-20T00:00:00.000Z"
    assert [%{type: "text/html"}] = task.links
    assert task.web_view_link == "https://tasks.google.com/task/task_abc123"
  end

  test "task struct defaults boolean and list fields" do
    task = Task.new!(%{task_id: "minimal"})

    assert task.deleted? == false
    assert task.hidden? == false
    assert task.links == []
    assert task.metadata == %{}
  end

  test "task struct rejects missing task_id" do
    assert {:error, _error} = Task.new(%{})
  end

  # --- MutationResult ---

  test "mutation result struct validates with Zoi" do
    result =
      ConnectorContracts.assert_struct_defaults(
        MutationResult,
        %{operation: :create, resource_type: :task_list, resource_id: "list_abc", status: :ok},
        metadata: %{}
      )

    assert result.operation == :create
    assert result.resource_type == :task_list
    assert result.resource_id == "list_abc"
    assert result.status == :ok
  end

  test "mutation result struct accepts empty optional fields" do
    result = MutationResult.new!(%{})
    assert result.metadata == %{}
  end

  test "mutation result struct accepts delete result" do
    result =
      MutationResult.new!(%{
        operation: :delete,
        resource_type: :task,
        resource_id: "task_xyz",
        status: :ok
      })

    assert result.operation == :delete
    assert result.resource_type == :task
    assert result.status == :ok
  end
end
