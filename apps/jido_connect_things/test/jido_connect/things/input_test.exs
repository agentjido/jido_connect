defmodule Jido.Connect.Things.InputTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Error
  alias Jido.Connect.Things.Input

  @target %{
    id: "VJ1edXTP9q3PmFDUuy8EQh",
    expected_modified_at: "2026-08-17T12:00:00Z"
  }

  test "parses every guarded V1 input contract" do
    assert {:ok, create} =
             Input.parse("things.todo.create", %{
               "title" => "Create",
               "notes" => "Note",
               "schedule" => "today",
               "deadline" => "2026-08-20",
               "tag_ids" => [],
               "area_id" => "MpkEei6ybkFS2n6SXvwfLf"
             })

    assert create.schedule == "today"

    valid = [
      {"things.todo.update", %{title: "New"}},
      {"things.todo.schedule", %{schedule: "2026-08-20"}},
      {"things.todo.deadline.set", %{deadline: "2026-08-20"}},
      {"things.todo.deadline.clear", %{}},
      {"things.todo.tags.set", %{tag_ids: []}},
      {"things.todo.move", %{project_id: "KGvAPpMrzHAKMdgMiERP1V"}},
      {"things.todo.complete", %{}},
      {"things.todo.cancel", %{}},
      {"things.todo.reopen", %{}},
      {"things.todo.trash", %{}},
      {"things.todo.restore", %{}}
    ]

    for {action, attrs} <- valid do
      assert {:ok, parsed} = Input.parse(action, Map.merge(@target, attrs))
      assert parsed.id == @target.id
      assert parsed.expected_modified_at == @target.expected_modified_at
    end
  end

  test "rejects invalid dates, schedules, duplicate keys, and unknown fields" do
    assert {:error, %Error.ValidationError{reason: :invalid_date}} =
             Input.parse("things.todo.schedule", Map.put(@target, :schedule, "later"))

    assert {:error, %Error.ValidationError{reason: :invalid_date}} =
             Input.parse("things.todo.deadline.set", Map.put(@target, :deadline, "2026-99-99"))

    assert {:error, %Error.ValidationError{reason: :invalid_datetime}} =
             Input.parse(
               "things.todo.complete",
               Map.put(@target, :expected_modified_at, "not-a-time")
             )

    assert {:error, %Error.ValidationError{reason: :duplicate_field}} =
             Input.parse("things.todo.update", %{
               "id" => @target.id,
               id: @target.id,
               expected_modified_at: @target.expected_modified_at,
               title: "New"
             })

    assert {:error, %Error.ValidationError{reason: :unknown_field}} =
             Input.parse("things.todo.create", %{title: "Create", recurrence: %{}})

    assert {:error, %Error.ValidationError{reason: :invalid_input}} =
             Input.parse("things.todo.create", :invalid)
  end
end
