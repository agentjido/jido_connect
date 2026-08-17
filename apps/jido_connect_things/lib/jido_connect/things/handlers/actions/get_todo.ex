defmodule Jido.Connect.Things.Handlers.Actions.GetTodo do
  @moduledoc false

  alias Jido.Connect.Things.{Query, ReadBoundary}

  def run(%{id: id}, %{context: context, credential_lease: lease}) do
    with {:ok, state} <- ReadBoundary.state(context, lease) do
      Query.get(state, id)
    end
  end
end
