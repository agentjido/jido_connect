defmodule Jido.Connect.Trello.Input do
  @moduledoc false

  alias Jido.Connect.Trello.Input.{Boards, Cards, Checklists, Lists}

  def validate("trello.board.get", input), do: Boards.validate_get(input)
  def validate("trello.label.list", input), do: Boards.validate_labels(input)
  def validate("trello.list.list", input), do: Lists.validate_list(input)
  def validate("trello.list.get", input), do: Lists.validate_get(input)
  def validate("trello.list.create", input), do: Lists.validate_create(input)
  def validate("trello.list.update", input), do: Lists.validate_update(input)
  def validate("trello.list.move", input), do: Lists.validate_move(input)
  def validate("trello.list.archive", input), do: Lists.validate_archive(input)
  def validate("trello.card.list", input), do: Cards.validate_list(input)
  def validate("trello.card.get", input), do: Cards.validate_get(input)
  def validate("trello.card.search", input), do: Cards.validate_search(input)
  def validate("trello.card.create", input), do: Cards.validate_create(input)
  def validate("trello.card.update", input), do: Cards.validate_update(input)
  def validate("trello.card.move", input), do: Cards.validate_move(input)
  def validate("trello.card.complete", input), do: Cards.validate_identity(input)
  def validate("trello.card.archive", input), do: Cards.validate_identity(input)
  def validate("trello.card.label.attach", input), do: Cards.validate_label(input)
  def validate("trello.card.label.detach", input), do: Cards.validate_label(input)
  def validate("trello.checklist.list", input), do: Checklists.validate_list(input)
  def validate("trello.checklist.create", input), do: Checklists.validate_create(input)
  def validate("trello.checklist.update", input), do: Checklists.validate_update(input)
  def validate("trello.checklist.item.create", input), do: Checklists.validate_item_create(input)
  def validate("trello.checklist.item.update", input), do: Checklists.validate_item_update(input)

  def validate(_action, _input), do: Jido.Connect.Trello.Input.Common.invalid(:action)
end
