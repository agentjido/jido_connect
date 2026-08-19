defmodule Jido.Connect.Trello.RouterTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Trello.{BoardIdentity, Contract, Router}

  @workspace_id "60eeea2273ccd82f506b3977"
  @board_object_id "6a61045166570c8531dc86a7"
  @board_ari "ari:cloud:trello::board/workspace/#{@workspace_id}/#{@board_object_id}"
  @list_ari "ari:cloud:trello::list/workspace/#{@workspace_id}/6a6105e754955319253c46ef"
  @card_ari "ari:cloud:trello::card/workspace/#{@workspace_id}/6a6105ed8ec975fc53dd6721"
  @label_ari "ari:cloud:trello::label/workspace/#{@workspace_id}/6a6105ed8ec975fc53dd6722"
  @checklist_ari "ari:cloud:trello::checklist/workspace/#{@workspace_id}/6a6105ed8ec975fc53dd6723"
  @item_ari "ari:cloud:trello::check-item/workspace/#{@workspace_id}/6a6105ed8ec975fc53dd6724"

  test "maps all reviewed actions to exact remote arguments" do
    cases = [
      {"trello.board.get", %{}, %{action: "get", boardId: identity().board_url}},
      {"trello.list.list", %{limit: 10, cursor: "next"},
       %{action: "list_by_board", boardId: @board_ari, limit: 10, cursor: "next"}},
      {"trello.list.get", %{id: @list_ari}, %{action: "get", listId: @list_ari}},
      {"trello.list.create", %{name: "New", position: "top"},
       %{action: "create", boardId: @board_ari, name: "New", pos: "top"}},
      {"trello.list.update", %{id: @list_ari, name: "New"},
       %{action: "update", listId: @list_ari, name: "New"}},
      {"trello.list.move", %{id: @list_ari, position: 2},
       %{action: "move", listId: @list_ari, pos: 2}},
      {"trello.list.archive", %{id: @list_ari}, %{action: "archive", listId: @list_ari}},
      {"trello.label.list", %{limit: 20, cursor: nil},
       %{action: "list_labels", boardId: @board_ari, limit: 20}},
      {"trello.card.list", %{state: "open", limit: 20, list_id: nil, cursor: nil},
       %{action: "list_by_board", boardIdOrUrl: @board_ari, filter: "open", limit: 20}},
      {"trello.card.list", %{state: "all", limit: 10, list_id: @list_ari, cursor: "c"},
       %{action: "list_by_list", listId: @list_ari, filter: "all", limit: 10, cursor: "c"}},
      {"trello.card.get", %{id: @card_ari}, %{action: "get", cardIdOrUrl: @card_ari}},
      {"trello.card.search", %{query: "blocked", limit: 5, partial: true, cursor: nil},
       %{
         action: "search_cards",
         query: "blocked",
         boardIds: [@board_ari],
         limit: 5,
         partial: true
       }},
      {"trello.card.create",
       %{list_id: @list_ari, name: "Card", description: nil, due: nil, position: nil},
       %{action: "create", listId: @list_ari, name: "Card"}},
      {"trello.card.update", %{card_id: @card_ari, name: "Card", description: nil},
       %{action: "update", cardId: @card_ari, name: "Card", desc: nil}},
      {"trello.card.move", %{card_id: @card_ari, list_id: @list_ari, position: "bottom"},
       %{action: "move", cardId: @card_ari, listId: @list_ari, pos: "bottom"}},
      {"trello.card.complete", %{card_id: @card_ari}, %{action: "mark_done", cardId: @card_ari}},
      {"trello.card.archive", %{card_id: @card_ari}, %{action: "archive", cardId: @card_ari}},
      {"trello.card.label.attach", %{card_id: @card_ari, label_id: @label_ari},
       %{action: "attach_label", cardId: @card_ari, labelId: @label_ari}},
      {"trello.card.label.detach", %{card_id: @card_ari, label_id: @label_ari},
       %{action: "detach_label", cardId: @card_ari, labelId: @label_ari}},
      {"trello.checklist.list", %{card_id: @card_ari, limit: 20, cursor: nil},
       %{action: "list_by_card", cardId: @card_ari, limit: 20}},
      {"trello.checklist.create", %{card_id: @card_ari, name: "Steps", position: 1},
       %{action: "create", cardId: @card_ari, name: "Steps", pos: 1}},
      {"trello.checklist.update",
       %{card_id: @card_ari, checklist_id: @checklist_ari, position: 2},
       %{action: "update", checklistId: @checklist_ari, pos: 2}},
      {"trello.checklist.item.create",
       %{card_id: @card_ari, checklist_id: @checklist_ari, text: "Do", position: nil},
       %{action: "add_item", checklistId: @checklist_ari, text: "Do"}},
      {"trello.checklist.item.update",
       %{
         card_id: @card_ari,
         checklist_id: @checklist_ari,
         item_id: @item_ari,
         text: "Done",
         checked: false,
         position: 3
       },
       %{
         action: "update_item",
         checklistId: @checklist_ari,
         itemId: @item_ari,
         text: "Done",
         checked: false,
         pos: 3
       }}
    ]

    for {action_id, input, expected} <- cases do
      descriptor = Contract.fetch_action!(action_id)
      assert Router.arguments(descriptor, input, identity()) == expected
      assert Router.tool(descriptor, input) == descriptor.tool
    end
  end

  test "card list changes only the reviewed remote action based on list_id" do
    descriptor = Contract.fetch_action!("trello.card.list")
    assert Router.remote_action(descriptor, %{list_id: nil}) == "list_by_board"
    assert Router.remote_action(descriptor, %{list_id: @list_ari}) == "list_by_list"
  end

  defp identity do
    %BoardIdentity{
      board_name: "Decentra Finance",
      board_url: "https://trello.com/b/Z4Htjzwu/decentra-finance",
      board_ari: @board_ari,
      board_object_id: @board_object_id,
      board_short_id: "Z4Htjzwu",
      workspace_object_id: @workspace_id
    }
  end
end
