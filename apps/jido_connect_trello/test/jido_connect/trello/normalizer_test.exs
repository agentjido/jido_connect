defmodule Jido.Connect.Trello.NormalizerTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Error
  alias Jido.Connect.Trello.Normalizer

  @board_id "ari:cloud:trello::board/workspace/60eeea2273ccd82f506b3977/6a61045166570c8531dc86a7"
  @list_id "ari:cloud:trello::list/workspace/60eeea2273ccd82f506b3977/6a6105e754955319253c46ef"
  @card_id "ari:cloud:trello::card/workspace/60eeea2273ccd82f506b3977/6a6105ed8ec975fc53dd6721"

  test "normalizes all supported Trello response families" do
    cases = [
      {"trello.board.get", %{}, board(), "workBoard"},
      {"trello.list.list", %{},
       %{"lists" => [list()], "pageInfo" => %{"hasNextPage" => false, "endCursor" => nil}},
       "workLists"},
      {"trello.list.get", %{}, list(), "workList"},
      {"trello.list.create", %{}, list(), "workListEffect"},
      {"trello.list.update", %{}, list(), "workListEffect"},
      {"trello.list.move", %{}, list(), "workListEffect"},
      {"trello.list.archive", %{}, list(), "workListEffect"},
      {"trello.label.list", %{},
       %{"labels" => [label()], "hasMore" => false, "nextCursor" => nil}, "workLabels"},
      {"trello.card.list", %{},
       %{
         "lists" => [%{"id" => @list_id, "name" => "Doing", "cards" => [card()]}],
         "hasNextPage" => false,
         "nextCursor" => nil
       }, "workCards"},
      {"trello.card.list", %{list_id: @list_id},
       %{"cards" => [card()], "pageInfo" => %{"hasNextPage" => false, "endCursor" => nil}},
       "workCards"},
      {"trello.card.search", %{}, %{"cards" => [card()], "hasMore" => false, "nextCursor" => nil},
       "workCards"},
      {"trello.card.get", %{}, card(), "workCard"},
      {"trello.card.create", %{}, card(), "workCardEffect"},
      {"trello.card.update", %{}, card(), "workCardEffect"},
      {"trello.card.move", %{}, card(), "workCardEffect"},
      {"trello.card.complete", %{}, card(), "workCardEffect"},
      {"trello.card.archive", %{}, card(), "workCardEffect"},
      {"trello.card.label.attach", %{}, card(), "workCardEffect"},
      {"trello.card.label.detach", %{}, card(), "workCardEffect"},
      {"trello.checklist.list", %{},
       %{"checklists" => [checklist()], "hasMore" => false, "nextCursor" => nil},
       "workChecklists"},
      {"trello.checklist.create", %{}, checklist(), "workChecklistEffect"},
      {"trello.checklist.update", %{}, checklist(), "workChecklistEffect"},
      {"trello.checklist.item.create", %{}, checklist_item(), "workChecklistItemEffect"},
      {"trello.checklist.item.update", %{}, checklist_item(), "workChecklistItemEffect"}
    ]

    for {action, input, payload, kind} <- cases do
      assert {:ok, %{kind: ^kind}} = Normalizer.normalize(action, input, structured(payload))
    end
  end

  test "accepts only structured content or one JSON text envelope" do
    assert {:ok, %{board: %{id: @board_id}}} =
             Normalizer.normalize("trello.board.get", %{}, structured(board()))

    text = %{"content" => [%{"type" => "text", "text" => Jason.encode!(board())}]}

    assert {:ok, %{board: %{id: @board_id}}} =
             Normalizer.normalize("trello.board.get", %{}, text)

    invalid = [
      %{},
      %{"structuredContent" => %{}},
      %{"content" => []},
      %{"content" => [%{"type" => "text", "text" => "{}"}, %{"type" => "text", "text" => "{}"}]},
      %{"content" => [%{"type" => "text", "text" => "[]"}]},
      %{"content" => [%{"type" => "text", "text" => "{"}]}
    ]

    for result <- invalid do
      assert {:error, %Error.ProviderError{provider: :trello, reason: :invalid_response}} =
               Normalizer.normalize("trello.board.get", %{}, result)
    end
  end

  test "fails closed on malformed success and redacts raw provider content" do
    invalid = [
      {"trello.board.get", Map.delete(board(), "name")},
      {"trello.board.get", Map.put(board(), "closed", "false")},
      {"trello.list.list", %{"lists" => [], "pageInfo" => []}},
      {"trello.label.list", %{"labels" => "secret-label-payload", "hasMore" => false}},
      {"trello.card.get", Map.put(card(), "due", "today")},
      {"trello.card.get", Map.put(card(), "labels", %{})},
      {"trello.card.search", %{"cards" => []}},
      {"trello.checklist.list", %{"checklists" => [], "hasMore" => "no"}},
      {"trello.checklist.item.update", %{"id" => "i", "name" => "I", "state" => "bad"}}
    ]

    for {action, payload} <- invalid do
      assert {:error, %Error.ProviderError{provider: :trello, reason: :invalid_response} = error} =
               Normalizer.normalize(action, %{}, structured(payload))

      rendered = inspect(error) <> inspect(Error.to_map(error))
      refute rendered =~ "secret-label-payload"
    end
  end

  test "classifies malformed read, write, and unknown action responses conservatively" do
    assert {:error, %Error.ProviderError{mutation?: false}} =
             Normalizer.normalize("trello.card.get", %{}, structured(%{}))

    assert {:error, %Error.ProviderError{mutation?: true}} =
             Normalizer.normalize("trello.card.update", %{}, structured(%{}))

    assert {:error, %Error.ProviderError{mutation?: true}} =
             Normalizer.normalize("trello.unknown", %{}, structured(%{}))
  end

  test "keeps fixed error reasons for malformed nested card identity" do
    cases = [
      {card() |> Map.delete("boardId") |> Map.put("board", []), :card_board_id},
      {card() |> Map.delete("listId") |> Map.put("list", []), :card_list_id},
      {Map.put(card(), "list", "invalid"), :card_list_name}
    ]

    for {payload, reason} <- cases do
      assert {:error, %Error.ProviderError{details: %{family: ^reason}}} =
               Normalizer.normalize("trello.card.get", %{}, structured(payload))
    end
  end

  defp structured(payload), do: %{"structuredContent" => payload}

  defp board do
    %{
      "id" => @board_id,
      "objectId" => "6a61045166570c8531dc86a7",
      "shortLink" => "Z4Htjzwu",
      "name" => "Decentra Finance",
      "url" => "https://trello.com/b/Z4Htjzwu/decentra-finance",
      "closed" => false,
      "description" => "Company work",
      "lastActivityAt" => "2026-08-11T12:00:00Z"
    }
  end

  defp list do
    %{
      "id" => @list_id,
      "objectId" => "6a6105e754955319253c46ef",
      "name" => "Doing",
      "position" => 16_384,
      "cards" => [%{"id" => @card_id, "name" => "Card"}]
    }
  end

  defp label do
    %{
      "id" =>
        "ari:cloud:trello::label/workspace/60eeea2273ccd82f506b3977/6a6105ed8ec975fc53dd6722",
      "objectId" => "6a6105ed8ec975fc53dd6722",
      "name" => "Blocked",
      "color" => "red",
      "uses" => 2
    }
  end

  defp checklist_item do
    %{
      "id" =>
        "ari:cloud:trello::check-item/workspace/60eeea2273ccd82f506b3977/6a6105ed8ec975fc53dd6724",
      "name" => "Verify metrics",
      "checked" => false,
      "position" => 16_384
    }
  end

  defp checklist do
    %{
      "id" =>
        "ari:cloud:trello::checklist/workspace/60eeea2273ccd82f506b3977/6a6105ed8ec975fc53dd6723",
      "objectId" => "6a6105ed8ec975fc53dd6723",
      "name" => "Release steps",
      "position" => 16_384,
      "items" => [checklist_item()]
    }
  end

  defp card do
    %{
      "id" => @card_id,
      "objectId" => "6a6105ed8ec975fc53dd6721",
      "name" => "Test card",
      "description" => "Test description",
      "url" => "https://trello.com/c/Abc123/test-card",
      "boardId" => @board_id,
      "listId" => @list_id,
      "list" => %{"id" => @list_id, "name" => "Doing"},
      "closed" => false,
      "complete" => false,
      "position" => 16_384,
      "lastActivityAt" => "2026-08-11T12:00:00Z",
      "due" => %{"date" => "2026-08-20T12:00:00Z", "complete" => false},
      "labels" => [label()],
      "checklists" => [checklist()]
    }
  end
end
