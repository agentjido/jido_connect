defmodule Jido.Connect.Trello.Normalizer.Card do
  @moduledoc false

  alias Jido.Connect.Trello.Normalizer.{Board, Checklist, Value}

  def normalize!(card) when is_map(card) do
    %{
      id: Value.required_string!(card, "id", :card_id),
      objectId: Value.optional_string!(card, "objectId", :card_object_id),
      name: Value.required_string!(card, "name", :card_name),
      description:
        Value.optional_string!(card, "description", :card_description) ||
          Value.optional_string!(card, "desc", :card_description) || "",
      url:
        Value.optional_string!(card, "url", :card_url) ||
          Value.optional_string!(card, "shortUrl", :card_url),
      boardId:
        Value.optional_string!(card, "boardId", :card_board_id) ||
          nested_id(card, "board", :card_board_id),
      listId:
        Value.optional_string!(card, "listId", :card_list_id) ||
          nested_id(card, "list", :card_list_id),
      listName: nested_name(card, "list", :card_list_name),
      closed: Value.optional_boolean!(card, "closed", :card_closed),
      complete: Value.optional_boolean!(card, "complete", :card_complete),
      position: Value.optional_number!(card, "position", :card_position),
      lastActivityAt: Value.optional_string!(card, "lastActivityAt", :card_activity),
      due: due!(card["due"]),
      labels: Value.embedded!(card["labels"], &Board.label!/1, :card_labels),
      checklists: Value.embedded!(card["checklists"], &Checklist.normalize!/1, :card_checklists)
    }
  end

  def normalize!(_card), do: Value.invalid!(:card)

  def summary!(card) when is_map(card) do
    %{
      id: Value.required_string!(card, "id", :card_summary_id),
      name: Value.required_string!(card, "name", :card_summary_name)
    }
  end

  def summary!(_card), do: Value.invalid!(:card_summary)

  def from_board!(%{"lists" => lists} = payload) when is_list(lists) do
    items =
      Enum.flat_map(lists, fn list ->
        list_id = Value.required_string!(list, "id", :card_list_id)
        list_name = Value.required_string!(list, "name", :card_list_name)

        case list["cards"] do
          cards when is_list(cards) -> Enum.map(cards, &with_list!(&1, list_id, list_name))
          _other -> Value.invalid!(:board_list_cards)
        end
      end)

    %{
      kind: "workCards",
      items: items,
      pageInfo: %{
        hasNextPage: Value.required_boolean!(payload, "hasNextPage", :card_page_state),
        endCursor: Value.optional_string!(payload, "nextCursor", :card_page_cursor)
      }
    }
  end

  def from_board!(_payload), do: Value.invalid!(:board_cards)

  def from_list!(%{"cards" => cards, "pageInfo" => page})
      when is_list(cards) and is_map(page) do
    %{
      kind: "workCards",
      items: Enum.map(cards, &normalize!/1),
      pageInfo: %{
        hasNextPage: Value.required_boolean!(page, "hasNextPage", :card_page_state),
        endCursor: Value.optional_string!(page, "endCursor", :card_page_cursor)
      }
    }
  end

  def from_list!(_payload), do: Value.invalid!(:list_cards)

  def search!(%{"cards" => cards} = payload) when is_list(cards) do
    %{
      kind: "workCards",
      items: Enum.map(cards, &normalize!/1),
      pageInfo: Value.cursor_page!(payload)
    }
  end

  def search!(_payload), do: Value.invalid!(:search_cards)

  defp with_list!(card, list_id, list_name) do
    card = normalize!(card)
    %{card | listId: card.listId || list_id, listName: card.listName || list_name}
  end

  defp due!(nil), do: nil

  defp due!(due) when is_map(due) do
    %{
      date: Value.optional_string!(due, "date", :card_due_date),
      complete: Value.required_boolean!(due, "complete", :card_due_complete)
    }
  end

  defp due!(_due), do: Value.invalid!(:card_due)

  defp nested_id(map, key, reason) do
    case map[key] do
      %{"id" => value} when is_binary(value) and value != "" -> value
      nil -> nil
      _other -> Value.invalid!(reason)
    end
  end

  defp nested_name(map, key, reason) do
    case map[key] do
      %{"name" => value} when is_binary(value) and value != "" -> value
      %{} -> nil
      nil -> nil
      _other -> Value.invalid!(reason)
    end
  end
end
