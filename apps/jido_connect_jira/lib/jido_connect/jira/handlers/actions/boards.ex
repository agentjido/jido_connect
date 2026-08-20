defmodule Jido.Connect.Jira.Handlers.Actions.ListBoards do
  @moduledoc false
  alias Jido.Connect.Jira.Handlers.Actions.Support

  def run(input, runtime) do
    opts =
      [
        name: Map.get(input, :name),
        project: Map.get(input, :project),
        type: Map.get(input, :type),
        limit: Map.get(input, :limit, 50),
        offset: Map.get(input, :offset, 0)
      ]
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)

    Support.call(runtime, & &1.list_boards(&2, opts))
  end
end

defmodule Jido.Connect.Jira.Handlers.Actions.GetBoard do
  @moduledoc false
  alias Jido.Connect.Jira.Handlers.Actions.Support
  def run(input, runtime), do: Support.call(runtime, & &1.get_board(input.id, &2))
end

defmodule Jido.Connect.Jira.Handlers.Actions.CreateBoard do
  @moduledoc false
  alias Jido.Connect.Jira.Handlers.Actions.Support
  alias Jido.Connect.Jira.Input.Boards

  def run(input, runtime) do
    with {:ok, input} <- Boards.create(input) do
      attrs = Map.take(input, [:name, :type, :filter_id, :location, :project])
      Support.call(runtime, & &1.create_board(attrs, &2))
    end
  end
end
