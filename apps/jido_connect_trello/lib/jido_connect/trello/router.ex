defmodule Jido.Connect.Trello.Router do
  @moduledoc false

  alias Jido.Connect.Trello.BoardIdentity

  def tool(descriptor, _input), do: descriptor.tool

  def remote_action(%{id: "trello.card.list"}, %{list_id: list_id})
      when is_binary(list_id),
      do: "list_by_list"

  def remote_action(descriptor, _input), do: descriptor.remote_action

  def arguments(%{id: "trello.board.get"}, _input, identity),
    do: %{action: "get", boardId: identity.board_url}

  def arguments(%{id: "trello.list.list"}, input, identity) do
    %{action: "list_by_board", boardId: identity.board_ari, limit: input.limit}
    |> maybe_put(:cursor, input.cursor)
  end

  def arguments(%{id: "trello.list.get"}, input, _identity),
    do: %{action: "get", listId: input.id}

  def arguments(%{id: "trello.list.create"}, input, identity) do
    %{action: "create", boardId: identity.board_ari, name: input.name}
    |> maybe_put(:pos, input.position)
  end

  def arguments(%{id: "trello.list.update"}, input, _identity),
    do: %{action: "update", listId: input.id, name: input.name}

  def arguments(%{id: "trello.list.move"}, input, _identity),
    do: %{action: "move", listId: input.id, pos: input.position}

  def arguments(%{id: "trello.list.archive"}, input, _identity),
    do: %{action: "archive", listId: input.id}

  def arguments(%{id: "trello.label.list"}, input, identity) do
    %{action: "list_labels", boardId: identity.board_ari, limit: input.limit}
    |> maybe_put(:cursor, input.cursor)
  end

  def arguments(%{id: "trello.card.list"} = descriptor, input, identity) do
    base = %{filter: input.state, limit: input.limit}

    base =
      case remote_action(descriptor, input) do
        "list_by_list" ->
          Map.merge(base, %{action: "list_by_list", listId: input.list_id})

        "list_by_board" ->
          Map.merge(base, %{action: "list_by_board", boardIdOrUrl: identity.board_ari})
      end

    maybe_put(base, :cursor, input.cursor)
  end

  def arguments(%{id: "trello.card.get"}, input, _identity),
    do: %{action: "get", cardIdOrUrl: input.id}

  def arguments(%{id: "trello.card.search"}, input, identity) do
    %{
      action: "search_cards",
      query: input.query,
      boardIds: [identity.board_ari],
      limit: input.limit,
      partial: input.partial
    }
    |> maybe_put(:cursor, input.cursor)
  end

  def arguments(%{id: "trello.card.create"}, input, _identity) do
    %{action: "create", listId: input.list_id, name: input.name}
    |> maybe_put(:desc, input.description)
    |> maybe_put(:due, input.due)
    |> maybe_put(:pos, input.position)
  end

  def arguments(%{id: "trello.card.update"}, input, _identity) do
    %{action: "update", cardId: input.card_id}
    |> maybe_put_present(:name, input, :name)
    |> maybe_put_present(:desc, input, :description)
    |> maybe_put_present(:due, input, :due)
  end

  def arguments(%{id: "trello.card.move"}, input, _identity) do
    %{action: "move", cardId: input.card_id, listId: input.list_id}
    |> maybe_put(:pos, input.position)
  end

  def arguments(%{id: "trello.card.complete"}, input, _identity),
    do: %{action: "mark_done", cardId: input.card_id}

  def arguments(%{id: "trello.card.archive"}, input, _identity),
    do: %{action: "archive", cardId: input.card_id}

  def arguments(%{id: "trello.card.label.attach"}, input, _identity),
    do: %{action: "attach_label", cardId: input.card_id, labelId: input.label_id}

  def arguments(%{id: "trello.card.label.detach"}, input, _identity),
    do: %{action: "detach_label", cardId: input.card_id, labelId: input.label_id}

  def arguments(%{id: "trello.checklist.list"}, input, _identity) do
    %{action: "list_by_card", cardId: input.card_id, limit: input.limit}
    |> maybe_put(:cursor, input.cursor)
  end

  def arguments(%{id: "trello.checklist.create"}, input, _identity) do
    %{action: "create", cardId: input.card_id, name: input.name}
    |> maybe_put(:pos, input.position)
  end

  def arguments(%{id: "trello.checklist.update"}, input, _identity) do
    %{action: "update", checklistId: input.checklist_id}
    |> maybe_put_present(:name, input, :name)
    |> maybe_put_present(:pos, input, :position)
  end

  def arguments(%{id: "trello.checklist.item.create"}, input, _identity) do
    %{action: "add_item", checklistId: input.checklist_id, text: input.text}
    |> maybe_put(:pos, input.position)
  end

  def arguments(%{id: "trello.checklist.item.update"}, input, _identity) do
    %{action: "update_item", checklistId: input.checklist_id, itemId: input.item_id}
    |> maybe_put_present(:text, input, :text)
    |> maybe_put_present(:checked, input, :checked)
    |> maybe_put_present(:pos, input, :position)
  end

  def arguments(_descriptor, _input, %BoardIdentity{}), do: %{}

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp maybe_put_present(map, provider_key, input, input_key) do
    if Map.has_key?(input, input_key),
      do: Map.put(map, provider_key, Map.fetch!(input, input_key)),
      else: map
  end
end
