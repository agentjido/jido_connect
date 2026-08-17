defmodule Jido.Connect.Things.StateTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Things.{Area, ChecklistItem, State, Tag, Todo}

  @task_id "A7h5eCi24RvAWKC3Hv3muf"
  @checklist_id "5uwoHPi5m5i8QJa6Rae6Cn"
  @area_id "MpkEei6ybkFS2n6SXvwfLf"
  @tag_id "JFdhhhp37fpryAKu8UXwzK"
  @project_id "KGvAPpMrzHAKMdgMiERP1V"
  @heading_id "CwhFwmHxjHkR7AFn9aJH9Q"

  test "materializes every V1 entity family and task safety field" do
    note = "Release notes"

    item = %{
      @task_id =>
        event("Task6", %{
          "tt" => "Ship release",
          "nt" => %{"_t" => "tx", "t" => 1, "v" => note, "ch" => :erlang.crc32(note)},
          "tp" => 0,
          "ss" => 0,
          "st" => 1,
          "sb" => 1,
          "tr" => false,
          "ix" => -42,
          "ti" => 7,
          "ar" => [],
          "pr" => [@project_id],
          "agr" => [@heading_id],
          "tg" => [@tag_id],
          "rt" => [],
          "rr" => nil,
          "icp" => false,
          "ato" => nil,
          "cd" => 1_700_000_000.25,
          "md" => 1_700_000_020.75,
          "sr" => 1_904_601_600,
          "tir" => 1_904_601_600,
          "dd" => 1_905_033_600,
          "sp" => nil
        }),
      @checklist_id =>
        event("ChecklistItem3", %{
          "tt" => "Verify package",
          "ss" => 0,
          "ts" => [@task_id],
          "ix" => 3,
          "cd" => 1_700_000_001.5
        }),
      @area_id => event("Area3", %{"tt" => "Operations", "tg" => [@tag_id], "ix" => 4}),
      @tag_id => event("Tag4", %{"tt" => "Focus", "sh" => "f", "pn" => [], "ix" => -1})
    }

    state = replay!([item])

    assert %Todo{} = task = state.tasks[@task_id]
    assert task.notes == note
    assert task.evening
    assert task.project_ids == [@project_id]
    assert task.heading_ids == [@heading_id]
    assert task.tag_ids == [@tag_id]
    assert task.deadline_at == ~U[2030-05-15 00:00:00Z]
    assert task.last_server_index == 1
    assert task.state_complete

    assert %ChecklistItem{task_id: @task_id} = state.checklist_items[@checklist_id]
    assert %Area{tag_ids: [@tag_id]} = state.areas[@area_id]
    assert %Tag{shortcut: "f"} = state.tags[@tag_id]

    assert [%Todo{checklist_item_ids: [@checklist_id]}] = State.active_tasks(state)
    assert state.write_safe?
    assert length(state.raw_events) == 4
  end

  test "distinguishes absent fields from explicit null clears" do
    create = %{
      @task_id =>
        event("Task6", %{
          "tt" => "Keep title",
          "nt" => "Keep note",
          "tp" => 0,
          "ss" => 0,
          "st" => 1,
          "dd" => 1_905_033_600,
          "tg" => [@tag_id]
        }),
      @tag_id => event("Tag4", %{"tt" => "Tag", "sh" => "f", "pn" => [@project_id]})
    }

    clear = %{
      @task_id => event("Task6", %{"dd" => nil, "tg" => nil}, 1),
      @tag_id => event("Tag4", %{"sh" => nil, "pn" => nil}, 1)
    }

    state = replay!([create, clear])

    assert state.tasks[@task_id].title == "Keep title"
    assert state.tasks[@task_id].notes == "Keep note"
    assert state.tasks[@task_id].deadline_at == nil
    assert state.tasks[@task_id].tag_ids == []
    assert state.tags[@tag_id].title == "Tag"
    assert state.tags[@tag_id].shortcut == nil
    assert state.tags[@tag_id].parent_ids == []
  end

  test "applies bounded note deltas and marks an invalid delta incomplete" do
    original = "Hello world"

    create =
      single_task(%{
        "nt" => %{"_t" => "tx", "t" => 1, "v" => original, "ch" => :erlang.crc32(original)}
      })

    valid_delta =
      single_task(
        %{
          "nt" => %{
            "_t" => "tx",
            "t" => 2,
            "ch" => :erlang.crc32(original),
            "ps" => [%{"r" => " Go", "p" => 5, "l" => 6, "ch" => 0}]
          }
        },
        1
      )

    valid_state = replay!([create, valid_delta])
    assert valid_state.tasks[@task_id].notes == "Hello Go"
    assert valid_state.tasks[@task_id].note_state == :complete

    invalid_delta =
      single_task(
        %{
          "nt" => %{
            "_t" => "tx",
            "t" => 2,
            "ch" => :erlang.crc32("Hello Go"),
            "ps" => [%{"r" => "bad", "p" => 99, "l" => 0, "ch" => 0}]
          }
        },
        1
      )

    unsafe_state = replay!([create, valid_delta, invalid_delta])
    assert unsafe_state.tasks[@task_id].notes == "Hello Go"
    assert unsafe_state.tasks[@task_id].note_state == :incomplete
    refute unsafe_state.tasks[@task_id].state_complete
    refute unsafe_state.write_safe?
  end

  test "retains unknown events and fields without unsafe interpretation" do
    state =
      replay!([
        %{
          @task_id => event("Task6", %{"tt" => "Task", "future-field" => %{"a" => 1}}),
          @area_id => %{"e" => "FutureEntity9", "t" => 0, "p" => %{"secret" => "value"}}
        }
      ])

    assert state.tasks[@task_id].unknown_fields == %{"future-field" => %{"a" => 1}}
    assert length(state.raw_events) == 2
    assert length(state.issues) == 2
    refute state.write_safe?
  end

  test "direct deletes and tombstones retain deleted state" do
    create = %{
      @task_id => event("Task6", %{"tt" => "Task"}),
      @checklist_id => event("ChecklistItem3", %{"tt" => "Item", "ts" => [@task_id]}),
      @area_id => event("Area3", %{"tt" => "Area"})
    }

    delete = %{@area_id => %{"e" => "Area3", "t" => 2}}

    tombstone = %{
      @tag_id => %{"e" => "Tombstone2", "t" => 0, "p" => %{"dloid" => @task_id}}
    }

    state = replay!([create, delete, tombstone])

    assert state.tasks[@task_id].deleted
    assert state.checklist_items[@checklist_id].deleted
    assert state.areas[@area_id].deleted
    assert MapSet.member?(state.tombstones, @task_id)
    assert State.active_tasks(state) == []
  end

  test "incremental replay equals a clean full replay" do
    first = single_task(%{"tt" => "First", "nt" => "Note"})
    second = single_task(%{"tt" => "Second", "dd" => nil}, 1)

    full = replay!([first, second])

    {:ok, partial} = State.apply_page(State.new(), [first], 0)
    {:ok, partial} = State.finish(partial, 1)
    {:ok, incremental} = State.apply_page(partial, [second], 1)
    {:ok, incremental} = State.finish(incremental, 2)

    assert incremental == full
  end

  test "rejects an unsafe history page structure" do
    assert {:error, %{reason: :invalid_server_item}} = State.apply_page(State.new(), ["bad"], 0)
    assert {:error, %{reason: :incremental_start_mismatch}} = State.apply_page(State.new(), [], 1)
  end

  defp replay!(items) do
    {:ok, state} = State.apply_page(State.new(), items, 0)
    {:ok, state} = State.finish(state, length(items))
    state
  end

  defp single_task(patch, action \\ 0) do
    payload =
      %{"tt" => "Task", "tp" => 0, "ss" => 0, "st" => 0, "tr" => false}
      |> Map.merge(patch)

    %{@task_id => event("Task6", payload, action)}
  end

  defp event(entity, payload, action \\ 0), do: %{"e" => entity, "t" => action, "p" => payload}
end
