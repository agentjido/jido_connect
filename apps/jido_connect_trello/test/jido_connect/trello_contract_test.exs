defmodule Jido.Connect.TrelloContractTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.MCP.Tool
  alias Jido.Connect.Trello

  @action_contract %{
    "trello.board.get" => {:board, :get, :read, :none},
    "trello.list.list" => {:list, :list, :read, :none},
    "trello.list.get" => {:list, :get, :read, :none},
    "trello.list.create" => {:list, :create, :write, :required_for_ai},
    "trello.list.update" => {:list, :update, :write, :required_for_ai},
    "trello.list.move" => {:list, :update, :write, :required_for_ai},
    "trello.list.archive" => {:list, :archive, :destructive, :always},
    "trello.label.list" => {:label, :list, :read, :none},
    "trello.card.list" => {:card, :list, :read, :none},
    "trello.card.get" => {:card, :get, :read, :none},
    "trello.card.search" => {:card, :search, :read, :none},
    "trello.card.create" => {:card, :create, :write, :required_for_ai},
    "trello.card.update" => {:card, :update, :write, :required_for_ai},
    "trello.card.move" => {:card, :update, :write, :required_for_ai},
    "trello.card.complete" => {:card, :update, :write, :required_for_ai},
    "trello.card.archive" => {:card, :archive, :destructive, :always},
    "trello.card.label.attach" => {:card_label, :update, :write, :required_for_ai},
    "trello.card.label.detach" => {:card_label, :update, :write, :required_for_ai},
    "trello.checklist.list" => {:checklist, :list, :read, :none},
    "trello.checklist.create" => {:checklist, :create, :write, :required_for_ai},
    "trello.checklist.update" => {:checklist, :update, :write, :required_for_ai},
    "trello.checklist.item.create" => {:checklist_item, :create, :write, :required_for_ai},
    "trello.checklist.item.update" => {:checklist_item, :update, :write, :required_for_ai}
  }

  test "declares exactly the reviewed Trello actions and an OAuth user profile" do
    spec = Trello.integration()

    assert spec.id == :trello
    assert spec.package == :jido_connect_trello
    assert spec.name == "Trello"
    assert spec.category == :productivity
    assert spec.triggers == []
    assert length(spec.actions) == 23

    assert Map.new(spec.actions, fn action ->
             {action.id, {action.resource, action.verb, action.risk, action.confirmation}}
           end) == @action_contract

    assert Enum.all?(spec.actions, &(&1.provider_idempotency? == false))

    assert [%{id: :oauth_user, kind: :oauth2, owner: :user} = profile] = spec.auth_profiles
    assert profile.default?
    assert profile.credential_fields == [:mcp_endpoint]
    assert profile.lease_fields == [:mcp_endpoint]
  end

  test "does not publish generic MCP actions and publishes reviewed packs" do
    action_ids = Trello.integration().actions |> Enum.map(& &1.id) |> MapSet.new()

    refute MapSet.member?(action_ids, "mcp.tools.list")
    refute MapSet.member?(action_ids, "mcp.tools.call")
    refute MapSet.member?(action_ids, "mcp.tool.call")

    [reader, editor, destructive] = Trello.catalog_packs()
    assert reader.id == :trello_reader
    assert length(reader.allowed_tools) == 8
    assert editor.id == :trello_editor
    assert length(editor.allowed_tools) == 21
    refute "trello.list.archive" in editor.allowed_tools
    refute "trello.card.archive" in editor.allowed_tools
    assert destructive.allowed_tools == ["trello.list.archive", "trello.card.archive"]

    assert Enum.all?([reader, editor, destructive], fn pack ->
             pack.filters == %{provider: :trello} and
               Enum.all?(pack.allowed_tools, &String.starts_with?(&1, "trello."))
           end)
  end

  test "owns exact fixed tool and remote action bindings" do
    expected = %{
      "trello.board.get" => {"trelloReadBoard", "get"},
      "trello.list.list" => {"trelloReadList", "list_by_board"},
      "trello.list.get" => {"trelloReadList", "get"},
      "trello.list.create" => {"trelloWriteList", "create"},
      "trello.list.update" => {"trelloWriteList", "update"},
      "trello.list.move" => {"trelloWriteList", "move"},
      "trello.list.archive" => {"trelloWriteList", "archive"},
      "trello.label.list" => {"trelloReadBoard", "list_labels"},
      "trello.card.list" => {"trelloReadCard", "list_by_board"},
      "trello.card.get" => {"trelloReadCard", "get"},
      "trello.card.search" => {"trelloSearch", "search_cards"},
      "trello.card.create" => {"trelloWriteCard", "create"},
      "trello.card.update" => {"trelloWriteCard", "update"},
      "trello.card.move" => {"trelloWriteCard", "move"},
      "trello.card.complete" => {"trelloWriteCard", "mark_done"},
      "trello.card.archive" => {"trelloWriteCard", "archive"},
      "trello.card.label.attach" => {"trelloWriteCard", "attach_label"},
      "trello.card.label.detach" => {"trelloWriteCard", "detach_label"},
      "trello.checklist.list" => {"trelloReadChecklist", "list_by_card"},
      "trello.checklist.create" => {"trelloWriteChecklist", "create"},
      "trello.checklist.update" => {"trelloWriteChecklist", "update"},
      "trello.checklist.item.create" => {"trelloWriteChecklist", "add_item"},
      "trello.checklist.item.update" => {"trelloWriteChecklist", "update_item"}
    }

    assert Map.new(Trello.Contract.actions(), fn descriptor ->
             {descriptor.id, {descriptor.tool, descriptor.remote_action}}
           end) == expected

    assert Trello.Contract.endpoint() == "https://mcp.trello.com/v1"
    assert Trello.Contract.endpoint_id() == "trello"
    assert map_size(Trello.Contract.tool_schemas()) == 8

    for {tool, schema} <- Trello.Contract.tool_schemas() do
      assert schema["type"] == "object"
      assert schema["additionalProperties"] == false
      assert Trello.Contract.schema_hash(tool) == Tool.schema_hash(schema)
      assert byte_size(Trello.Contract.schema_hash(tool)) == 64
    end

    assert Enum.all?(Trello.Contract.actions(), fn descriptor ->
             Trello.Contract.mutation?(descriptor.id) == descriptor.mutation?
           end)

    assert Trello.Contract.mutation?("trello.unknown")
  end

  test "publishes bounded snake-case action fields" do
    actions = Map.new(Trello.integration().actions, &{&1.id, &1})

    list = fields(actions["trello.list.list"])
    assert list.limit.default == 25
    assert list.limit.minimum == 1
    assert list.limit.maximum == 50
    assert list.cursor.max_length == 2_048

    cards = fields(actions["trello.card.list"])
    assert cards.state.enum == ["open", "archived", "all"]
    assert cards.list_id.max_length == 128
    refute Map.has_key?(cards, :listId)

    search = fields(actions["trello.card.search"])
    assert search.query.max_length == 500
    assert search.limit.maximum == 100
    assert search.partial.default == false

    create = fields(actions["trello.card.create"])
    assert create.list_id.required?
    assert create.name.max_length == 512
    assert create.description.max_length == 2_048

    update = fields(actions["trello.checklist.item.update"])
    assert update.card_id.required?
    assert update.checklist_id.required?
    assert update.item_id.required?
    assert update.text.max_length == 16_384

    refute Enum.any?(actions, fn {_id, action} ->
             Map.has_key?(fields(action), :endpoint_id) or
               Map.has_key?(fields(action), :tool_name) or
               Map.has_key?(fields(action), :action)
           end)
  end

  test "registers generated modules and package discovery" do
    assert Application.get_env(:jido_connect_trello, :jido_connect_providers) == [Trello]
    assert length(Trello.jido_action_modules()) == 23
    assert Trello.jido_sensor_modules() == []
    assert Trello.jido_plugin_module() == Jido.Connect.Trello.Plugin

    assert %Connect.Catalog.Manifest{id: :trello, package: :jido_connect_trello} =
             Trello.jido_connect_manifest()

    for module <- Trello.jido_action_modules() do
      assert {:module, ^module} = Code.ensure_loaded(module)
      assert function_exported?(module, :run, 2)
    end
  end

  test "all generated action modules execute through the typed handler" do
    for module <- Trello.jido_action_modules() do
      assert {:error, _error} = module.run(%{}, %{})
    end
  end

  test "all write actions have bounded previews" do
    write_actions = Enum.reject(Trello.integration().actions, &(&1.risk == :read))
    assert length(write_actions) == 15
    assert Enum.all?(write_actions, &(is_atom(&1.preview) and not is_nil(&1.preview)))

    assert Jido.Connect.Trello.Previews.CardCreate.preview(
             %{
               list_id: "list-1",
               name: "Card",
               description: String.duplicate("x", 10),
               due: "2026-08-20T12:00:00Z",
               position: "top"
             },
             %{}
           ) == %{
             operation: "card.create",
             list_id: "list-1",
             name: "Card",
             description_characters: 10,
             due: "2026-08-20T12:00:00Z",
             position: "top"
           }

    assert Jido.Connect.Trello.Previews.CardArchive.preview(%{card_id: "card-1"}, %{}) ==
             %{operation: "card.archive", card_id: "card-1"}

    preview_inputs = %{
      Jido.Connect.Trello.Previews.ListCreate => %{name: "List", position: "top"},
      Jido.Connect.Trello.Previews.ListUpdate => %{id: "list-1", name: "List"},
      Jido.Connect.Trello.Previews.ListMove => %{id: "list-1", position: "bottom"},
      Jido.Connect.Trello.Previews.ListArchive => %{id: "list-1"},
      Jido.Connect.Trello.Previews.CardUpdate => %{
        card_id: "card-1",
        description: "new text"
      },
      Jido.Connect.Trello.Previews.CardMove => %{card_id: "card-1", list_id: "list-1"},
      Jido.Connect.Trello.Previews.CardComplete => %{card_id: "card-1"},
      Jido.Connect.Trello.Previews.CardLabelAttach => %{
        card_id: "card-1",
        label_id: "label-1"
      },
      Jido.Connect.Trello.Previews.CardLabelDetach => %{
        card_id: "card-1",
        label_id: "label-1"
      },
      Jido.Connect.Trello.Previews.ChecklistCreate => %{card_id: "card-1", name: "Steps"},
      Jido.Connect.Trello.Previews.ChecklistUpdate => %{
        card_id: "card-1",
        checklist_id: "checklist-1",
        name: "Steps"
      },
      Jido.Connect.Trello.Previews.ChecklistItemCreate => %{
        card_id: "card-1",
        checklist_id: "checklist-1",
        text: "Do work"
      },
      Jido.Connect.Trello.Previews.ChecklistItemUpdate => %{
        card_id: "card-1",
        checklist_id: "checklist-1",
        item_id: "item-1",
        checked: true
      }
    }

    for {preview, input} <- preview_inputs do
      result = preview.preview(input, %{})
      assert is_binary(result.operation)
      refute Map.has_key?(result, :description)
      refute Map.has_key?(result, :text)
    end
  end

  defp fields(action), do: Map.new(action.input, &{&1.name, &1})
end
