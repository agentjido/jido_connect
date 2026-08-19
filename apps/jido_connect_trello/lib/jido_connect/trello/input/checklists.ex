defmodule Jido.Connect.Trello.Input.Checklists do
  @moduledoc false

  alias Jido.Connect.Trello.{Contract, Input.Common}

  def validate_list(input) do
    with :ok <- Common.strict(input, [:card_id, :cursor, :limit]),
         card_id = Common.get(input, :card_id),
         cursor = Common.get(input, :cursor),
         limit = Common.get(input, :limit) || 25,
         :ok <- Common.ari(card_id, "card"),
         :ok <-
           Common.optional(cursor, &Common.required_string(&1, Contract.cursor_max(), :cursor)),
         :ok <- Common.integer(limit, 1, 100, :limit) do
      {:ok, %{card_id: card_id, cursor: cursor, limit: limit}}
    end
  end

  def validate_create(input) do
    with :ok <- Common.strict(input, [:card_id, :name, :position]),
         card_id = Common.get(input, :card_id),
         name = Common.get(input, :name),
         position = Common.get(input, :position),
         :ok <- Common.ari(card_id, "card"),
         :ok <- Common.required_string(name, Contract.name_max(), :name),
         :ok <- Common.optional(position, &Common.position(&1, :position)) do
      {:ok, %{card_id: card_id, name: name, position: position}}
    end
  end

  def validate_update(input) do
    with :ok <- Common.strict(input, [:card_id, :checklist_id, :name, :position]),
         :ok <- Common.require_present(input, [:name, :position]),
         card_id = Common.get(input, :card_id),
         checklist_id = Common.get(input, :checklist_id),
         name = Common.get(input, :name),
         position = Common.get(input, :position),
         :ok <- Common.ari(card_id, "card"),
         :ok <- Common.ari(checklist_id, "checklist"),
         :ok <-
           Common.validate_present(
             input,
             :name,
             name,
             &Common.required_string(&1, Contract.name_max(), :name)
           ),
         :ok <-
           Common.validate_present(input, :position, position, &Common.position(&1, :position)) do
      normalized = %{card_id: card_id, checklist_id: checklist_id}
      normalized = Common.put_present(normalized, input, :name)
      {:ok, Common.put_present(normalized, input, :position)}
    end
  end

  def validate_item_create(input) do
    with :ok <- Common.strict(input, [:card_id, :checklist_id, :text, :position]),
         card_id = Common.get(input, :card_id),
         checklist_id = Common.get(input, :checklist_id),
         text = Common.get(input, :text),
         position = Common.get(input, :position),
         :ok <- Common.ari(card_id, "card"),
         :ok <- Common.ari(checklist_id, "checklist"),
         :ok <- Common.required_string(text, Contract.checklist_text_max(), :text),
         :ok <- Common.optional(position, &Common.position(&1, :position)) do
      {:ok, %{card_id: card_id, checklist_id: checklist_id, text: text, position: position}}
    end
  end

  def validate_item_update(input) do
    with :ok <-
           Common.strict(input, [
             :card_id,
             :checklist_id,
             :item_id,
             :text,
             :checked,
             :position
           ]),
         :ok <- Common.require_present(input, [:text, :checked, :position]),
         card_id = Common.get(input, :card_id),
         checklist_id = Common.get(input, :checklist_id),
         item_id = Common.get(input, :item_id),
         text = Common.get(input, :text),
         checked = Common.get(input, :checked),
         position = Common.get(input, :position),
         :ok <- Common.ari(card_id, "card"),
         :ok <- Common.ari(checklist_id, "checklist"),
         :ok <- Common.ari(item_id, "check-item"),
         :ok <-
           Common.validate_present(
             input,
             :text,
             text,
             &Common.required_string(&1, Contract.checklist_text_max(), :text)
           ),
         :ok <- Common.validate_present(input, :checked, checked, &Common.boolean(&1, :checked)),
         :ok <-
           Common.validate_present(input, :position, position, &Common.position(&1, :position)) do
      normalized = %{card_id: card_id, checklist_id: checklist_id, item_id: item_id}
      normalized = Common.put_present(normalized, input, :text)
      normalized = Common.put_present(normalized, input, :checked)
      {:ok, Common.put_present(normalized, input, :position)}
    end
  end
end
