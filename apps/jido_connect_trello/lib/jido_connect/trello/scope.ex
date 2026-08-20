defmodule Jido.Connect.Trello.Scope do
  @moduledoc false

  alias Jido.Connect.Error
  alias Jido.Connect.Trello.{BoardIdentity, Normalizer}

  @maximum_scope_pages 100

  def verify_board(%BoardIdentity{} = identity, %{board: board}) do
    expected = %{
      id: identity.board_ari,
      objectId: identity.board_object_id,
      shortId: identity.board_short_id,
      name: identity.board_name,
      url: identity.board_url
    }

    if Map.take(board, Map.keys(expected)) != expected do
      {:error,
       Error.auth("Trello board does not match the selected connection",
         reason: :trello_board_mismatch,
         details: %{provider: :trello}
       )}
    else
      if board.closed do
        {:error,
         Error.auth("The selected Trello board is archived",
           reason: :trello_board_archived,
           details: %{provider: :trello}
         )}
      else
        :ok
      end
    end
  end

  def verify_board(_identity, _result), do: scope_error(:trello_board_mismatch)

  def verify_request(action, input, identity, call) do
    with :ok <- validate_input_workspace(action, input, identity) do
      case action do
        action
        when action in ~w(trello.list.get trello.list.update trello.list.move trello.list.archive) ->
          assert_list(input.id, identity, call)

        "trello.card.list" ->
          if input.list_id, do: assert_list(input.list_id, identity, call), else: :ok

        "trello.card.get" ->
          assert_card(input.id, identity, call)

        "trello.card.create" ->
          assert_list(input.list_id, identity, call)

        "trello.card.move" ->
          with :ok <- assert_card(input.card_id, identity, call),
               do: assert_list(input.list_id, identity, call)

        action when action in ~w(trello.card.update trello.card.complete trello.card.archive) ->
          assert_card(input.card_id, identity, call)

        action when action in ~w(trello.card.label.attach trello.card.label.detach) ->
          with :ok <- assert_card(input.card_id, identity, call),
               do: assert_label(input.label_id, identity, call)

        action when action in ~w(trello.checklist.list trello.checklist.create) ->
          assert_card(input.card_id, identity, call)

        action
        when action in ~w(trello.checklist.update trello.checklist.item.create trello.checklist.item.update) ->
          with :ok <- assert_card(input.card_id, identity, call),
               do: assert_checklist(input.card_id, input.checklist_id, call)

        _action ->
          :ok
      end
    end
  end

  def verify_result(action, result, identity) do
    cards =
      case {action, result} do
        {"trello.card.get", %{card: card}} ->
          [card]

        {action, %{card: card}}
        when action in ~w(trello.card.create trello.card.update trello.card.move trello.card.complete trello.card.archive trello.card.label.attach trello.card.label.detach) ->
          [card]

        {action, %{items: cards}} when action in ~w(trello.card.list trello.card.search) ->
          cards

        _other ->
          []
      end

    Enum.reduce_while(cards, :ok, fn card, :ok ->
      case card_board(card, identity) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp assert_card(card_id, identity, call) do
    search_pages(
      card_id,
      :trello_card_board_mismatch,
      call,
      %{
        tool: "trelloReadCard",
        arguments: %{
          action: "list_by_board",
          boardIdOrUrl: identity.board_ari,
          filter: "all",
          limit: 50
        },
        action: "trello.card.list",
        input: %{state: "all", limit: 50}
      }
    )
  end

  defp assert_list(list_id, identity, call) do
    search_pages(
      list_id,
      :trello_list_board_mismatch,
      call,
      %{
        tool: "trelloReadList",
        arguments: %{action: "list_by_board", boardId: identity.board_ari, limit: 50},
        action: "trello.list.list",
        input: %{limit: 50}
      }
    )
  end

  defp assert_label(label_id, identity, call) do
    search_pages(
      label_id,
      :trello_label_board_mismatch,
      call,
      %{
        tool: "trelloReadBoard",
        arguments: %{action: "list_labels", boardId: identity.board_ari, limit: 100},
        action: "trello.label.list",
        input: %{limit: 100}
      }
    )
  end

  defp assert_checklist(card_id, checklist_id, call) do
    search_pages(
      checklist_id,
      :trello_checklist_card_mismatch,
      call,
      %{
        tool: "trelloReadChecklist",
        arguments: %{action: "list_by_card", cardId: card_id, limit: 100},
        action: "trello.checklist.list",
        input: %{card_id: card_id, limit: 100}
      }
    )
  end

  defp search_pages(target_id, mismatch, call, source) do
    search_page(target_id, mismatch, call, source, nil, MapSet.new(), 0)
  end

  defp search_page(_target_id, _mismatch, _call, _source, _cursor, _seen, count)
       when count >= @maximum_scope_pages,
       do: scope_error(:trello_scope_page_limit)

  defp search_page(target_id, mismatch, call, source, cursor, seen, count) do
    with {:ok, raw} <- call.(source.tool, maybe_cursor(source.arguments, cursor), false),
         {:ok, %{items: items, pageInfo: page}} <-
           Normalizer.normalize(source.action, Map.put(source.input, :cursor, cursor), raw) do
      cond do
        Enum.any?(items, &matches_target?(&1, target_id)) ->
          :ok

        page.hasNextPage ->
          with {:ok, next} <- next_cursor(page, seen) do
            search_page(
              target_id,
              mismatch,
              call,
              source,
              next,
              MapSet.put(seen, next),
              count + 1
            )
          end

        true ->
          scope_error(mismatch)
      end
    end
  end

  defp validate_input_workspace(action, input, identity) do
    fields =
      case action do
        action
        when action in ~w(trello.list.get trello.list.update trello.list.move trello.list.archive) ->
          [:id]

        "trello.card.list" ->
          [:list_id]

        "trello.card.create" ->
          [:list_id]

        "trello.card.update" ->
          [:card_id]

        "trello.card.move" ->
          [:card_id, :list_id]

        action when action in ~w(trello.card.complete trello.card.archive) ->
          [:card_id]

        action when action in ~w(trello.card.label.attach trello.card.label.detach) ->
          [:card_id, :label_id]

        action when action in ~w(trello.checklist.list trello.checklist.create) ->
          [:card_id]

        action when action in ~w(trello.checklist.update trello.checklist.item.create) ->
          [:card_id, :checklist_id]

        "trello.checklist.item.update" ->
          [:card_id, :checklist_id, :item_id]

        _action ->
          []
      end

    Enum.reduce_while(fields, :ok, fn field, :ok ->
      case Map.get(input, field) do
        nil ->
          {:cont, :ok}

        value ->
          if ari_workspace(value) == identity.workspace_object_id,
            do: {:cont, :ok},
            else: {:halt, scope_error(:trello_workspace_mismatch)}
      end
    end)
  end

  defp ari_workspace(value) when is_binary(value) do
    case String.split(value, "/") do
      [_, "workspace", workspace, _object] -> workspace
      _other -> nil
    end
  end

  defp ari_workspace(_value), do: nil

  defp card_board(%{boardId: board_id}, identity) when board_id == identity.board_ari, do: :ok
  defp card_board(_card, _identity), do: scope_error(:trello_card_board_mismatch)

  defp next_cursor(%{endCursor: cursor}, seen)
       when is_binary(cursor) and cursor != "" do
    if MapSet.member?(seen, cursor),
      do: scope_error(:trello_scope_cursor_repeated),
      else: {:ok, cursor}
  end

  defp next_cursor(_page, _seen), do: scope_error(:trello_scope_cursor_missing)

  defp maybe_cursor(arguments, nil), do: arguments
  defp maybe_cursor(arguments, cursor), do: Map.put(arguments, :cursor, cursor)

  defp matches_target?(item, target_id) when is_map(item) do
    Enum.any?([:id, :objectId, :url], fn key -> Map.get(item, key) == target_id end)
  end

  defp scope_error(reason) do
    {:error,
     Error.auth("Trello resource is outside the selected board",
       reason: reason,
       details: %{provider: :trello}
     )}
  end
end
