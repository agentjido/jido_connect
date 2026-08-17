defmodule Jido.Connect.Things.QueryTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Error

  alias Jido.Connect.Things.{
    Area,
    ChecklistItem,
    Query,
    State,
    Tag,
    Todo
  }

  @today ~D[2026-08-17]
  @today_at ~U[2026-08-17 09:00:00Z]
  @future_at ~U[2026-08-20 09:00:00Z]
  @area_id "Area00000000000000000001"
  @project_id "Project000000000000001"
  @heading_id "Heading000000000000001"
  @tag_id "Tag000000000000000000001"

  test "lists every V1 view with stable public task data" do
    state = state_fixture()

    assert ids(state, "inbox") == ["TaskInbox0000000000001"]
    assert ids(state, "today") == ["TaskEvening00000000001", "TaskToday0000000000001"]
    assert ids(state, "evening") == ["TaskEvening00000000001"]
    assert ids(state, "anytime") == ["TaskAnytime00000000001"]
    assert ids(state, "someday") == ["TaskSomeday00000000001"]
    assert ids(state, "upcoming") == ["TaskUpcoming0000000001"]
    assert ids(state, "logbook") == ["TaskCanceled0000000001", "TaskComplete0000000001"]
    assert ids(state, "trash") == ["TaskTrash0000000000001"]

    assert {:ok, %{count: 9, freshness: freshness}} =
             Query.list(state, %{view: "all", status: "all", tag_ids: [], limit: 100},
               today: @today
             )

    assert freshness == %{
             source: "provider",
             provider_head: 12,
             state_complete: true,
             issue_count: 0
           }
  end

  test "filters tasks by text, status, relation, and date ranges" do
    state = state_fixture()

    input = %{
      view: "all",
      status: "open",
      query: "private match",
      area_id: @area_id,
      project_id: @project_id,
      heading_id: @heading_id,
      tag_ids: [@tag_id],
      deadline_from: "2026-08-17",
      deadline_to: "2026-08-17",
      scheduled_from: "2026-08-17",
      scheduled_to: "2026-08-17",
      limit: 10
    }

    assert {:ok, %{todos: [todo]}} = Query.search(state, input, today: @today)
    assert todo.id == "TaskToday0000000000001"
    assert todo.notes == "Private match"
    assert todo.area_ids == [@area_id]
    assert todo.project_ids == [@project_id]
    assert todo.heading_ids == [@heading_id]
    assert todo.tag_ids == [@tag_id]
    assert todo.deadline_at == "2026-08-17T09:00:00Z"
  end

  test "gets exact or unique-prefix records and rejects ambiguous prefixes" do
    state = state_fixture()

    assert {:ok, %{todo: %{id: "TaskInbox0000000000001"}}} =
             Query.get(state, "TaskInbox0000000000001")

    assert {:ok, %{todo: %{id: @project_id, type: "project"}}} =
             Query.get(state, "Project000")

    assert {:error, %Error.ProviderError{reason: :ambiguous_todo_id}} =
             Query.get(state, "Task")

    assert {:error, %Error.ProviderError{reason: :todo_not_found}} =
             Query.get(state, "Missing")
  end

  test "lists projects, headings, areas, tags, and checklist details" do
    state = state_fixture()

    state = %{
      state
      | tasks:
          Map.put(
            state.tasks,
            "ProjectClosed0000000001",
            todo("ProjectClosed0000000001", "Closed project",
              type: :project,
              status: :completed
            )
          )
    }

    assert {:ok, %{projects: [%{id: @project_id}], count: 1}} =
             Query.references(state, :project)

    assert {:ok, %{headings: [%{id: @heading_id, project_ids: [@project_id]}], count: 1}} =
             Query.references(state, :heading)

    assert {:ok, %{areas: [%{id: @area_id, tag_ids: [@tag_id]}], count: 1}} =
             Query.references(state, :area)

    assert {:ok, %{tags: [%{id: @tag_id, parent_ids: [@tag_id]}], count: 1}} =
             Query.references(state, :tag)

    assert {:ok, %{todo: todo}} = Query.get(state, "TaskToday0000000000001")

    assert todo.checklist_items == [
             %{
               id: "Checklist000000000000001",
               title: "Verify result",
               status: "open",
               stopped_at: nil,
               position: 1,
               created_at: nil,
               modified_at: nil,
               state_complete: true,
               last_server_index: 12
             }
           ]
  end

  test "rejects invalid filters and reversed date ranges" do
    state = state_fixture()

    assert {:error, %Error.ProviderError{reason: :invalid_filter}} =
             Query.list(state, %{view: "invalid"}, today: @today)

    assert {:error, %Error.ProviderError{reason: :invalid_filter}} =
             Query.search(state, %{query: "  \t "}, today: @today)

    assert {:error, %Error.ProviderError{reason: :invalid_date_filter}} =
             Query.list(state, %{deadline_from: "not-a-date"}, today: @today)

    assert {:error, %Error.ProviderError{reason: :invalid_date_range}} =
             Query.list(
               state,
               %{deadline_from: "2026-08-18", deadline_to: "2026-08-17"},
               today: @today
             )
  end

  test "rejects unsupported task events but allows unrelated unknown history" do
    state = state_fixture()

    task_issue = %{
      reason: :unsupported_event,
      details: %{entity: "Task6", action: 99}
    }

    unsafe = %{state | write_safe?: false, issues: [task_issue]}

    assert {:error, %Error.ProviderError{reason: :unsupported_task_event}} =
             Query.list(unsafe, %{view: "all"}, today: @today)

    unrelated_issue = %{
      reason: :unsupported_event,
      details: %{entity: "FutureEntity9", action: 0}
    }

    readable = %{state | write_safe?: false, issues: [unrelated_issue]}
    assert {:ok, %{count: 9}} = Query.list(readable, %{view: "all"}, today: @today)
  end

  defp ids(state, view) do
    {:ok, %{todos: todos}} =
      Query.list(state, %{view: view, status: "all", tag_ids: [], limit: 100}, today: @today)

    Enum.map(todos, & &1.id)
  end

  defp state_fixture do
    tasks = [
      todo("TaskInbox0000000000001", "Inbox", schedule: :inbox),
      todo("TaskToday0000000000001", "Today",
        scheduled_at: @today_at,
        deadline_at: @today_at,
        notes: "Private match",
        area_ids: [@area_id],
        project_ids: [@project_id],
        heading_ids: [@heading_id],
        tag_ids: [@tag_id]
      ),
      todo("TaskEvening00000000001", "Evening", scheduled_at: @today_at, evening: true),
      todo("TaskAnytime00000000001", "Anytime", schedule: :anytime),
      todo("TaskSomeday00000000001", "Someday", schedule: :someday),
      todo("TaskUpcoming0000000001", "Upcoming", schedule: :anytime, scheduled_at: @future_at),
      todo("TaskComplete0000000001", "Complete", status: :completed),
      todo("TaskCanceled0000000001", "Canceled", status: :canceled),
      todo("TaskTrash0000000000001", "Trash", in_trash: true),
      todo(@project_id, "Project", type: :project),
      todo(@heading_id, "Heading", type: :heading, project_ids: [@project_id])
    ]

    checklist =
      ChecklistItem.new!(%{
        id: "Checklist000000000000001",
        task_id: "TaskToday0000000000001",
        title: "Verify result",
        position: 1,
        last_server_index: 12
      })

    %{
      State.new()
      | provider_head: 12,
        last_server_index: 12,
        tasks: Map.new(tasks, &{&1.id, &1}),
        checklist_items: %{checklist.id => checklist},
        areas: %{
          @area_id => Area.new!(%{id: @area_id, title: "Area", tag_ids: [@tag_id], position: 1})
        },
        tags: %{
          @tag_id => Tag.new!(%{id: @tag_id, title: "Tag", parent_ids: [@tag_id], position: 1})
        }
    }
  end

  defp todo(id, title, attrs) do
    %{id: id, title: title, status: :open, type: :task, last_server_index: 12}
    |> Map.merge(Map.new(attrs))
    |> Todo.new!()
  end
end
