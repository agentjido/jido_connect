defmodule Jido.Connect.ThingsTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.{Catalog, Error}
  alias Jido.Connect.Things
  alias Jido.Connect.Things.Input

  @action_ids [
    "things.todo.list",
    "things.todo.get",
    "things.todo.search",
    "things.todo.create",
    "things.todo.update",
    "things.project.list",
    "things.heading.list",
    "things.area.list",
    "things.tag.list"
  ]

  test "registers the experimental provider and nine generated actions" do
    spec = Things.integration()

    assert spec.id == :things
    assert spec.package == :jido_connect_things
    assert spec.category == :task_management
    assert spec.status == :experimental
    assert spec.tags == [:tasks, :personal_productivity, :unofficial_api]
    assert Enum.map(spec.actions, & &1.id) == @action_ids

    assert Application.get_env(:jido_connect_things, :jido_connect_providers) == [Things]
    assert [%Catalog.Entry{id: :things}] = Catalog.discover(modules: [Things])

    assert Code.ensure_loaded?(Jido.Connect.Things.Plugin)
    assert Code.ensure_loaded?(Jido.Connect.Things.Actions.ListInboxTodos)
    assert Code.ensure_loaded?(Jido.Connect.Things.Actions.GetTodo)
    assert Code.ensure_loaded?(Jido.Connect.Things.Actions.SearchTodos)
    assert Code.ensure_loaded?(Jido.Connect.Things.Actions.CreateInboxTodo)
    assert Code.ensure_loaded?(Jido.Connect.Things.Actions.UpdateInboxTodo)
    assert Code.ensure_loaded?(Jido.Connect.Things.Actions.ListProjects)
    assert Code.ensure_loaded?(Jido.Connect.Things.Actions.ListHeadings)
    assert Code.ensure_loaded?(Jido.Connect.Things.Actions.ListAreas)
    assert Code.ensure_loaded?(Jido.Connect.Things.Actions.ListTags)
  end

  test "declares host-owned credential lease fields and guarded write metadata" do
    spec = Things.integration()
    profile = hd(spec.auth_profiles)

    assert profile.id == :things_cloud_password
    assert profile.kind == :api_key
    assert profile.credential_fields == [:email, :password]
    assert profile.lease_fields == [:email, :password]

    actions = Map.new(spec.actions, &{&1.id, &1})
    assert actions["things.todo.list"].risk == :read
    assert actions["things.todo.list"].confirmation == :none

    for id <- ["things.todo.create", "things.todo.update"] do
      assert actions[id].risk == :external_write
      assert actions[id].confirmation == :required_for_ai
      assert actions[id].metadata.prepare_commit_required?
      assert actions[id].metadata.strict_input?
      assert actions[id].metadata.unofficial_api?
    end
  end

  test "uses strict input schemas with length and range contracts" do
    actions = Map.new(Things.integration().actions, &{&1.id, &1})

    assert {:ok, %{view: "inbox", status: "all", tag_ids: [], limit: 25}} =
             Zoi.parse(actions["things.todo.list"].input_schema, %{})

    assert {:error, _errors} =
             Zoi.parse(actions["things.todo.list"].input_schema, %{limit: 0})

    assert {:error, _errors} =
             Zoi.parse(actions["things.todo.list"].input_schema, %{unknown: true})

    assert {:ok, %{title: "A"}} =
             Zoi.parse(actions["things.todo.create"].input_schema, %{title: "A"})

    assert {:error, _errors} =
             Zoi.parse(actions["things.todo.create"].input_schema, %{title: ""})

    assert {:error, _errors} =
             Zoi.parse(actions["things.todo.create"].input_schema, %{
               title: String.duplicate("a", 2_001)
             })

    assert {:error, _errors} =
             Zoi.parse(actions["things.todo.create"].input_schema, %{
               title: "A",
               project: "not-supported"
             })

    assert {:error, %Error.ValidationError{reason: :no_changes}} =
             Input.parse("things.todo.update", %{
               id: "VJ1edXTP9q3PmFDUuy8EQh",
               expected_modified_at: "2026-08-17T12:00:00Z"
             })
  end

  test "publishes reader and editor packs without raw or destructive tools" do
    assert [reader, editor] = Things.catalog_packs()

    assert reader.id == :things_inbox_reader

    assert reader.allowed_tools == [
             "things.todo.list",
             "things.todo.get",
             "things.todo.search",
             "things.project.list",
             "things.heading.list",
             "things.area.list",
             "things.tag.list"
           ]

    assert editor.id == :things_inbox_editor

    assert editor.allowed_tools == [
             "things.todo.list",
             "things.todo.get",
             "things.todo.search",
             "things.project.list",
             "things.heading.list",
             "things.area.list",
             "things.tag.list",
             "things.todo.create",
             "things.todo.update"
           ]

    refute Enum.any?(editor.allowed_tools, &String.contains?(&1, ["delete", "trash", "raw"]))
  end

  test "catalog data contains no protocol secrets" do
    entry = [modules: [Things]] |> Catalog.discover() |> hd() |> Catalog.to_map()
    serialized = inspect(entry)

    refute serialized =~ "history-key"
    refute serialized =~ "commit body"
    refute serialized =~ "credential lease"
    assert serialized =~ "unofficial_api"
  end
end
