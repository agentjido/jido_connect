defmodule Jido.Connect.Trello.Input.Lists do
  @moduledoc false

  alias Jido.Connect.Trello.{Contract, Input.Common}

  def validate_list(input) do
    with :ok <- Common.strict(input, [:cursor, :limit]),
         cursor = Common.get(input, :cursor),
         limit = Common.get(input, :limit) || 25,
         :ok <-
           Common.optional(cursor, &Common.required_string(&1, Contract.cursor_max(), :cursor)),
         :ok <- Common.integer(limit, 1, 50, :limit) do
      {:ok, %{cursor: cursor, limit: limit}}
    end
  end

  def validate_get(input), do: identity(input)
  def validate_archive(input), do: identity(input)

  def validate_create(input) do
    with :ok <- Common.strict(input, [:name, :position]),
         name = Common.get(input, :name),
         position = Common.get(input, :position),
         :ok <- Common.required_string(name, Contract.name_max(), :name),
         :ok <- Common.optional(position, &Common.position(&1, :position)) do
      {:ok, %{name: name, position: position}}
    end
  end

  def validate_update(input) do
    with :ok <- Common.strict(input, [:id, :name]),
         id = Common.get(input, :id),
         name = Common.get(input, :name),
         :ok <- Common.ari(id, "list"),
         :ok <- Common.required_string(name, Contract.name_max(), :name) do
      {:ok, %{id: id, name: name}}
    end
  end

  def validate_move(input) do
    with :ok <- Common.strict(input, [:id, :position]),
         id = Common.get(input, :id),
         position = Common.get(input, :position),
         :ok <- Common.ari(id, "list"),
         :ok <- Common.position(position, :position) do
      {:ok, %{id: id, position: position}}
    end
  end

  defp identity(input) do
    with :ok <- Common.strict(input, [:id]),
         id = Common.get(input, :id),
         :ok <- Common.ari(id, "list") do
      {:ok, %{id: id}}
    end
  end
end
