defmodule Jido.Connect.Google.Tasks.CatalogPacksTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Tasks

  @readonly_tools [
    "google.tasks.tasklist.list",
    "google.tasks.tasklist.get",
    "google.tasks.task.list",
    "google.tasks.task.get"
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
end
