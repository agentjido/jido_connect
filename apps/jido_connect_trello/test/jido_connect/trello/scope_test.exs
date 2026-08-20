defmodule Jido.Connect.Trello.ScopeTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Error
  alias Jido.Connect.Trello.{BoardIdentity, Scope}

  @workspace_id "60eeea2273ccd82f506b3977"
  @board_object_id "6a61045166570c8531dc86a7"
  @board_ari "ari:cloud:trello::board/workspace/#{@workspace_id}/#{@board_object_id}"
  @list_ari "ari:cloud:trello::list/workspace/#{@workspace_id}/6a6105e754955319253c46ef"
  @card_ari "ari:cloud:trello::card/workspace/#{@workspace_id}/6a6105ed8ec975fc53dd6721"
  @label_ari "ari:cloud:trello::label/workspace/#{@workspace_id}/6a6105ed8ec975fc53dd6722"
  @checklist_ari "ari:cloud:trello::checklist/workspace/#{@workspace_id}/6a6105ed8ec975fc53dd6723"

  test "checks the complete board identity and card result scope" do
    identity = identity()

    assert :ok = Scope.verify_board(identity, %{board: normalized_board(false)})

    assert {:error, %Error.AuthError{reason: :trello_board_archived}} =
             Scope.verify_board(identity, %{board: normalized_board(true)})

    assert {:error, %Error.AuthError{reason: :trello_board_mismatch}} =
             Scope.verify_board(identity, %{board: %{normalized_board(false) | name: "Other"}})

    assert :ok =
             Scope.verify_result(
               "trello.card.get",
               %{card: %{boardId: @board_ari}},
               identity
             )

    assert {:error, %Error.AuthError{reason: :trello_card_board_mismatch}} =
             Scope.verify_result(
               "trello.card.search",
               %{items: [%{boardId: "other-board"}]},
               identity
             )
  end

  test "checks list membership and rejects a different ARI workspace" do
    call = fn "trelloReadList", arguments, false ->
      assert arguments.action == "list_by_board"
      {:ok, structured(lists_page([list()], false, nil))}
    end

    assert :ok =
             Scope.verify_request("trello.card.create", %{list_id: @list_ari}, identity(), call)

    other_workspace =
      String.replace(@list_ari, @workspace_id, "aaaaaaaaaaaaaaaaaaaaaaaa")

    assert {:error, %Error.AuthError{reason: :trello_workspace_mismatch}} =
             Scope.verify_request(
               "trello.card.create",
               %{list_id: other_workspace},
               identity(),
               call
             )

    empty_call = fn "trelloReadList", _arguments, false ->
      {:ok, structured(lists_page([], false, nil))}
    end

    assert {:error, %Error.AuthError{reason: :trello_list_board_mismatch}} =
             Scope.verify_request(
               "trello.list.get",
               %{id: @list_ari},
               identity(),
               empty_call
             )
  end

  test "checks card, label, and checklist membership" do
    call = fn
      "trelloReadCard", %{action: "list_by_board"}, false ->
        {:ok, structured(cards_page([card()], false, nil))}

      "trelloReadCard", %{action: "get", cardIdOrUrl: @card_ari}, false ->
        {:ok, structured(card())}

      "trelloReadBoard", %{action: "list_labels", boardId: @board_ari}, false ->
        {:ok, structured(%{"labels" => [label()], "hasMore" => false, "nextCursor" => nil})}

      "trelloReadChecklist", %{action: "list_by_card", cardId: @card_ari}, false ->
        {:ok,
         structured(%{
           "checklists" => [checklist()],
           "hasMore" => false,
           "nextCursor" => nil
         })}
    end

    assert :ok =
             Scope.verify_request(
               "trello.card.label.attach",
               %{card_id: @card_ari, label_id: @label_ari},
               identity(),
               call
             )

    assert :ok =
             Scope.verify_request(
               "trello.checklist.update",
               %{card_id: @card_ari, checklist_id: @checklist_ari},
               identity(),
               call
             )
  end

  test "stops paged membership checks when the requested ID is found" do
    owner = self()

    call = fn "trelloReadList", arguments, false ->
      send(owner, {:list_page, arguments})

      case Map.get(arguments, :cursor) do
        nil -> {:ok, structured(lists_page([], true, "second-page"))}
        "second-page" -> {:ok, structured(lists_page([list()], true, "unused-next-page"))}
      end
    end

    assert :ok =
             Scope.verify_request("trello.card.create", %{list_id: @list_ari}, identity(), call)

    assert_receive {:list_page, %{action: "list_by_board"} = first_arguments}
    refute Map.has_key?(first_arguments, :cursor)
    assert_receive {:list_page, %{cursor: "second-page"}}
    refute_receive {:list_page, _arguments}
  end

  test "rejects repeated cursors and stops at the page limit" do
    repeated_call = fn "trelloReadList", _arguments, false ->
      {:ok, structured(lists_page([], true, "repeated"))}
    end

    assert {:error, %Error.AuthError{reason: :trello_scope_cursor_repeated}} =
             Scope.verify_request(
               "trello.card.create",
               %{list_id: @list_ari},
               identity(),
               repeated_call
             )

    counter = make_ref()
    Process.put(counter, 0)

    page_limit_call = fn "trelloReadList", _arguments, false ->
      page = Process.get(counter) + 1
      Process.put(counter, page)
      {:ok, structured(lists_page([], true, Integer.to_string(page)))}
    end

    assert {:error, %Error.AuthError{reason: :trello_scope_page_limit}} =
             Scope.verify_request(
               "trello.card.create",
               %{list_id: @list_ari},
               identity(),
               page_limit_call
             )

    assert Process.get(counter) == 100
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

  defp normalized_board(closed) do
    %{
      id: @board_ari,
      objectId: @board_object_id,
      shortId: "Z4Htjzwu",
      name: "Decentra Finance",
      url: "https://trello.com/b/Z4Htjzwu/decentra-finance",
      closed: closed
    }
  end

  defp lists_page(lists, has_next, cursor) do
    %{
      "lists" => lists,
      "pageInfo" => %{"hasNextPage" => has_next, "endCursor" => cursor}
    }
  end

  defp cards_page(cards, has_next, cursor) do
    %{
      "lists" => [%{"id" => @list_ari, "name" => "Doing", "cards" => cards}],
      "hasNextPage" => has_next,
      "nextCursor" => cursor
    }
  end

  defp list do
    %{"id" => @list_ari, "name" => "Doing"}
  end

  defp card do
    %{
      "id" => @card_ari,
      "name" => "Card",
      "boardId" => @board_ari,
      "listId" => @list_ari
    }
  end

  defp label do
    %{"id" => @label_ari, "name" => "Blocked"}
  end

  defp checklist do
    %{"id" => @checklist_ari, "name" => "Steps"}
  end

  defp structured(payload), do: %{"structuredContent" => payload}
end
