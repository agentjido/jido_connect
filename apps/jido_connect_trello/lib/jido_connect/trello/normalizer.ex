defmodule Jido.Connect.Trello.Normalizer do
  @moduledoc false

  alias Jido.Connect.Error
  alias Jido.Connect.Trello.Contract
  alias Jido.Connect.Trello.Normalizer.{Board, Card, Checklist, List, Value}

  def normalize(action, input, result) do
    try do
      payload = Value.payload!(result)
      {:ok, normalize_payload(action, input, payload)}
    catch
      {:trello_normalization_error, reason} ->
        {:error,
         Error.provider("Trello MCP returned an invalid response",
           provider: :trello,
           reason: :invalid_response,
           delivery: :response_received,
           mutation?: Contract.mutation?(action),
           provider_idempotency?: false,
           details: %{family: reason}
         )}
    end
  end

  defp normalize_payload("trello.board.get", _input, payload),
    do: %{kind: "workBoard", board: Board.normalize!(payload)}

  defp normalize_payload("trello.list.list", _input, payload) do
    {items, page_info} = List.page!(payload)
    %{kind: "workLists", items: items, pageInfo: page_info}
  end

  defp normalize_payload("trello.list.get", _input, payload),
    do: %{kind: "workList", list: List.normalize!(payload)}

  defp normalize_payload("trello.list." <> effect, _input, payload)
       when effect in ~w(create update move archive) do
    %{kind: "workListEffect", effect: effect, list: List.normalize!(payload)}
  end

  defp normalize_payload("trello.label.list", _input, payload) do
    {items, page_info} = Board.labels_page!(payload)
    %{kind: "workLabels", items: items, pageInfo: page_info}
  end

  defp normalize_payload("trello.card.list", input, payload) do
    if Map.get(input, :list_id), do: Card.from_list!(payload), else: Card.from_board!(payload)
  end

  defp normalize_payload("trello.card.search", _input, payload), do: Card.search!(payload)

  defp normalize_payload("trello.card.get", _input, payload),
    do: %{kind: "workCard", card: Card.normalize!(payload)}

  defp normalize_payload("trello.card." <> effect, _input, payload)
       when effect in ~w(create update move complete archive) do
    %{kind: "workCardEffect", effect: effect, card: Card.normalize!(payload)}
  end

  defp normalize_payload("trello.card.label." <> effect, _input, payload)
       when effect in ~w(attach detach) do
    %{kind: "workCardEffect", effect: effect <> "-label", card: Card.normalize!(payload)}
  end

  defp normalize_payload("trello.checklist.list", _input, payload) do
    {items, page_info} = Checklist.page!(payload)
    %{kind: "workChecklists", items: items, pageInfo: page_info}
  end

  defp normalize_payload("trello.checklist." <> effect, _input, payload)
       when effect in ~w(create update) do
    %{
      kind: "workChecklistEffect",
      effect: effect,
      checklist: Checklist.normalize!(payload)
    }
  end

  defp normalize_payload("trello.checklist.item." <> effect, _input, payload)
       when effect in ~w(create update) do
    %{kind: "workChecklistItemEffect", effect: effect, item: Checklist.item!(payload)}
  end

  defp normalize_payload(_action, _input, _payload), do: Value.invalid!(:unknown_action)
end
