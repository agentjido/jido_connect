defmodule Jido.Connect.Trello.Input.Cards do
  @moduledoc false

  alias Jido.Connect.Trello.{Contract, Input.Common}

  def validate_list(input) do
    with :ok <- Common.strict(input, [:list_id, :state, :cursor, :limit]),
         list_id = Common.get(input, :list_id),
         state = Common.get(input, :state) || "open",
         cursor = Common.get(input, :cursor),
         limit = Common.get(input, :limit) || 25,
         :ok <- Common.optional(list_id, &Common.ari(&1, "list")),
         :ok <- Common.one_of(state, ["open", "archived", "all"], :state),
         :ok <-
           Common.optional(cursor, &Common.required_string(&1, Contract.cursor_max(), :cursor)),
         :ok <- Common.integer(limit, 1, 50, :limit) do
      {:ok, %{list_id: list_id, state: state, cursor: cursor, limit: limit}}
    end
  end

  def validate_get(input) do
    with :ok <- Common.strict(input, [:id]),
         id = Common.get(input, :id),
         :ok <- Common.card_locator(id) do
      {:ok, %{id: id}}
    end
  end

  def validate_search(input) do
    with :ok <- Common.strict(input, [:query, :cursor, :limit, :partial]),
         query = Common.get(input, :query),
         cursor = Common.get(input, :cursor),
         limit = Common.get(input, :limit) || 10,
         partial = Common.get(input, :partial) || false,
         :ok <- Common.required_string(query, Contract.query_max(), :query),
         :ok <-
           Common.optional(cursor, &Common.required_string(&1, Contract.cursor_max(), :cursor)),
         :ok <- Common.integer(limit, 1, 100, :limit),
         :ok <- Common.boolean(partial, :partial) do
      {:ok, %{query: query, cursor: cursor, limit: limit, partial: partial}}
    end
  end

  def validate_create(input) do
    with :ok <- Common.strict(input, [:list_id, :name, :description, :due, :position]),
         list_id = Common.get(input, :list_id),
         name = Common.get(input, :name),
         description = Common.get(input, :description),
         due = Common.get(input, :due),
         position = Common.get(input, :position),
         :ok <- Common.ari(list_id, "list"),
         :ok <- Common.required_string(name, Contract.name_max(), :name),
         :ok <-
           Common.optional(
             description,
             &Common.plain_string(&1, Contract.description_max(), :description)
           ),
         :ok <- Common.optional(due, &Common.utc_datetime(&1, :due)),
         :ok <- Common.optional(position, &Common.position(&1, :position)) do
      {:ok,
       %{
         list_id: list_id,
         name: name,
         description: description,
         due: due,
         position: position
       }}
    end
  end

  def validate_update(input) do
    with :ok <- Common.strict(input, [:card_id, :name, :description, :due]),
         :ok <- Common.require_present(input, [:name, :description, :due]),
         card_id = Common.get(input, :card_id),
         name = Common.get(input, :name),
         description = Common.get(input, :description),
         due = Common.get(input, :due),
         :ok <- Common.ari(card_id, "card"),
         :ok <-
           Common.validate_present(
             input,
             :name,
             name,
             &Common.required_string(&1, Contract.name_max(), :name)
           ),
         :ok <-
           Common.validate_present(
             input,
             :description,
             description,
             &Common.plain_string(&1, Contract.description_max(), :description)
           ),
         :ok <- Common.validate_present(input, :due, due, &Common.utc_datetime(&1, :due)) do
      normalized = %{card_id: card_id}
      normalized = Common.put_present(normalized, input, :name)
      normalized = Common.put_present(normalized, input, :description)
      {:ok, Common.put_present(normalized, input, :due)}
    end
  end

  def validate_move(input) do
    with :ok <- Common.strict(input, [:card_id, :list_id, :position]),
         card_id = Common.get(input, :card_id),
         list_id = Common.get(input, :list_id),
         position = Common.get(input, :position),
         :ok <- Common.ari(card_id, "card"),
         :ok <- Common.ari(list_id, "list"),
         :ok <- Common.optional(position, &Common.position(&1, :position)) do
      {:ok, %{card_id: card_id, list_id: list_id, position: position}}
    end
  end

  def validate_identity(input) do
    with :ok <- Common.strict(input, [:card_id]),
         card_id = Common.get(input, :card_id),
         :ok <- Common.ari(card_id, "card") do
      {:ok, %{card_id: card_id}}
    end
  end

  def validate_label(input) do
    with :ok <- Common.strict(input, [:card_id, :label_id]),
         card_id = Common.get(input, :card_id),
         label_id = Common.get(input, :label_id),
         :ok <- Common.ari(card_id, "card"),
         :ok <- Common.ari(label_id, "label") do
      {:ok, %{card_id: card_id, label_id: label_id}}
    end
  end
end
