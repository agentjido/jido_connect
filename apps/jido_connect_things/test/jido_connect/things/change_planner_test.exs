defmodule Jido.Connect.Things.ChangePlannerTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Error
  alias Jido.Connect.Things.{Area, ChangePlanner, State, Tag, Todo}

  @task_id "VJ1edXTP9q3PmFDUuy8EQh"
  @area_id "MpkEei6ybkFS2n6SXvwfLf"
  @tag_id "JFdhhhp37fpryAKu8UXwzK"
  @project_id "KGvAPpMrzHAKMdgMiERP1V"
  @heading_id "CwhFwmHxjHkR7AFn9aJH9Q"
  @modified_at ~U[2026-08-17 12:00:00Z]
  @timestamp 1_786_978_800.0
  @today ~D[2026-08-17]

  test "plans a full V1 create with a stable UUID and safe preview" do
    input = %{
      title: "Create",
      notes: "Private note",
      schedule: "today",
      deadline: "2026-08-20",
      tag_ids: [@tag_id],
      area_id: @area_id
    }

    assert {:ok, planned} = plan("things.todo.create", input)
    assert planned.risk == :normal
    assert planned.operation.id == @task_id
    assert planned.preview.target_id == @task_id
    assert planned.preview.after.notes.length == 12
    refute inspect(planned.preview) =~ "Private note"

    payload = payload(planned)
    assert payload["tt"] == "Create"
    assert payload["st"] == 1
    assert payload["sr"] == 1_786_924_800.0
    assert payload["tir"] == 1_786_924_800.0
    assert payload["dd"] == 1_787_184_000.0
    assert payload["tg"] == [@tag_id]
    assert payload["ar"] == [@area_id]
    assert payload["pr"] == []
    assert payload["agr"] == []
    assert payload["rr"] == nil
    assert payload["rt"] == []
    assert payload["ato"] == nil
  end

  test "uses the creation timestamp as the first concurrency token" do
    created = state_fixture(task: %{created_at: @modified_at, modified_at: nil})

    assert {:ok, planned} =
             plan("things.todo.update", target_input(%{title: "First update"}), created)

    assert planned.expected_modified_at == DateTime.to_iso8601(@modified_at)
  end

  test "normalizes a container create or move out of Inbox to Anytime" do
    assert {:ok, create} =
             plan("things.todo.create", %{title: "Create", project_id: @project_id, tag_ids: []})

    assert create.preview.after.schedule == "anytime"
    assert payload(create)["st"] == 1

    assert {:ok, move} =
             plan("things.todo.move", target_input(%{project_id: @project_id}))

    assert move.preview.before.schedule == "inbox"
    assert move.preview.after.schedule == "anytime"
    assert payload(move)["pr"] == [@project_id]
    assert payload(move)["ar"] == []
    assert payload(move)["agr"] == []
    assert payload(move)["st"] == 1
  end

  test "plans high-risk note replacement without exposing note text" do
    state = state_fixture(task: %{notes: "Old private note"})
    input = target_input(%{notes: "New private note"})

    assert {:ok, planned} = plan("things.todo.update", input, state)
    assert planned.risk == :high
    assert planned.preview.before.notes.length == 16
    assert planned.preview.after.notes.length == 16
    refute inspect(planned.preview) =~ "private note"
    assert payload(planned)["nt"]["v"] == "New private note"
  end

  test "plans deadline, tag, relation, status, Trash, and restore changes" do
    assert {:ok, deadline} =
             plan("things.todo.deadline.set", target_input(%{deadline: "2026-08-20"}))

    assert payload(deadline)["dd"] == 1_787_184_000.0

    assert {:ok, clear} = plan("things.todo.deadline.clear", target_input())
    assert Map.fetch!(payload(clear), "dd") == nil

    assert {:ok, tags} = plan("things.todo.tags.set", target_input(%{tag_ids: [@tag_id]}))
    assert tags.preview.before.tag_ids == []
    assert tags.preview.after.tag_ids == [@tag_id]

    assert {:ok, heading} =
             plan(
               "things.todo.move",
               target_input(%{
                 project_id: @project_id,
                 heading_id: @heading_id,
                 schedule: "anytime"
               })
             )

    assert payload(heading)["pr"] == [@project_id]
    assert payload(heading)["agr"] == [@heading_id]

    for {action, status, wire_status} <- [
          {"things.todo.complete", "completed", 3},
          {"things.todo.cancel", "canceled", 2}
        ] do
      assert {:ok, planned} = plan(action, target_input())
      assert planned.preview.after.status == status
      assert payload(planned)["ss"] == wire_status
      assert payload(planned)["sp"] == @timestamp
    end

    completed = state_fixture(task: %{status: :completed, stopped_at: @modified_at})
    assert {:ok, reopen} = plan("things.todo.reopen", target_input(), completed)
    assert reopen.preview.before.status == "completed"
    assert reopen.preview.after.status == "open"
    assert payload(reopen)["ss"] == 0
    assert Map.fetch!(payload(reopen), "sp") == nil

    assert {:ok, trash} = plan("things.todo.trash", target_input())
    assert trash.risk == :destructive
    assert payload(trash)["tr"]

    trashed = state_fixture(task: %{in_trash: true})
    assert {:ok, restore} = plan("things.todo.restore", target_input(), trashed)
    refute payload(restore)["tr"]
  end

  test "plans all schedule combinations from the V1 table" do
    expected = [
      {"inbox", {0, nil, nil, 0}},
      {"anytime", {1, nil, nil, 0}},
      {"someday", {2, nil, nil, 0}},
      {"today", {1, 1_786_924_800.0, 1_786_924_800.0, 0}},
      {"evening", {1, 1_786_924_800.0, 1_786_924_800.0, 1}},
      {"2026-08-20", {2, 1_787_184_000.0, 1_787_184_000.0, 0}},
      {"2026-08-16", {1, 1_786_838_400.0, 1_786_838_400.0, 0}}
    ]

    for {schedule, expected_fields} <- expected do
      assert {:ok, planned} =
               plan("things.todo.schedule", target_input(%{schedule: schedule}))

      value = payload(planned)
      assert {value["st"], value["sr"], value["tir"], value["sb"]} == expected_fields
    end
  end

  test "isolates unrelated issues and rejects unsafe targets, transitions, and destinations" do
    unsafe = %{state_fixture() | write_safe?: false}

    assert {:ok, _planned} =
             plan("things.todo.update", target_input(%{title: "New"}), unsafe)

    incomplete = state_fixture(task: %{state_complete: false})

    assert_error(
      :unsafe_task_state,
      "things.todo.update",
      target_input(%{title: "New"}),
      incomplete
    )

    recurring = state_fixture(task: %{recurrence_state_present: true})

    assert_error(
      :unsafe_task_state,
      "things.todo.update",
      target_input(%{title: "New"}),
      recurring
    )

    assert_error(
      :target_in_trash,
      "things.todo.update",
      target_input(%{title: "New"}),
      state_fixture(task: %{in_trash: true})
    )

    assert_error(:invalid_status_transition, "things.todo.reopen", target_input())
    assert_error(:not_in_trash, "things.todo.restore", target_input())

    assert_error(
      :invalid_tag_destination,
      "things.todo.tags.set",
      target_input(%{tag_ids: [@area_id]})
    )

    assert_error(
      :heading_project_mismatch,
      "things.todo.move",
      target_input(%{project_id: @project_id, heading_id: @heading_id}),
      state_fixture(heading: %{project_ids: [@area_id]})
    )

    assert_error(
      :container_cannot_be_inbox,
      "things.todo.move",
      target_input(%{area_id: @area_id, schedule: "inbox"})
    )
  end

  defp plan(action, input, state \\ state_fixture()) do
    ChangePlanner.prepare(action, input, state,
      id: @task_id,
      timestamp: @timestamp,
      today: @today
    )
  end

  defp assert_error(reason, action, input, state \\ state_fixture()) do
    assert {:error, %Error.ProviderError{reason: ^reason}} = plan(action, input, state)
  end

  defp target_input(changes \\ %{}) do
    Map.merge(
      %{id: @task_id, expected_modified_at: DateTime.to_iso8601(@modified_at)},
      changes
    )
  end

  defp payload(planned) do
    planned.operation.body |> Jason.decode!() |> Map.fetch!(@task_id) |> Map.fetch!("p")
  end

  defp state_fixture(opts \\ []) do
    task = todo(@task_id, :task, Keyword.get(opts, :task, %{}))
    project = todo(@project_id, :project, %{})

    heading =
      todo(@heading_id, :heading, Keyword.get(opts, :heading, %{project_ids: [@project_id]}))

    %{
      State.new()
      | provider_head: 4,
        last_server_index: 4,
        tasks: Map.new([task, project, heading], &{&1.id, &1}),
        areas: %{@area_id => Area.new!(%{id: @area_id, title: "Area"})},
        tags: %{@tag_id => Tag.new!(%{id: @tag_id, title: "Tag"})}
    }
  end

  defp todo(id, type, changes) do
    %{
      id: id,
      title: Atom.to_string(type),
      notes: "",
      modified_at: @modified_at,
      status: :open,
      schedule: :inbox,
      type: type
    }
    |> Map.merge(changes)
    |> Todo.new!()
  end
end
