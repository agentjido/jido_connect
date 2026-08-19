defmodule Jido.Connect.Trello.Input.Boards do
  @moduledoc false

  alias Jido.Connect.Trello.Contract
  alias Jido.Connect.Trello.Input.Common

  def validate_get(input) do
    with :ok <- Common.strict(input, []) do
      {:ok, %{}}
    end
  end

  def validate_labels(input) do
    with :ok <- Common.strict(input, [:cursor, :limit]),
         cursor = Common.get(input, :cursor),
         limit = Common.get(input, :limit) || 25,
         :ok <-
           Common.optional(cursor, &Common.required_string(&1, Contract.cursor_max(), :cursor)),
         :ok <- Common.integer(limit, 1, 100, :limit) do
      {:ok, %{cursor: cursor, limit: limit}}
    end
  end
end
