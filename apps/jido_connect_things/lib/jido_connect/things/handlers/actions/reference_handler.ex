defmodule Jido.Connect.Things.Handlers.Actions.ReferenceHandler do
  @moduledoc false

  alias Jido.Connect.Things.{Query, ReadBoundary}

  def run(kind, %{context: context, credential_lease: lease}) do
    with {:ok, state} <- ReadBoundary.state(context, lease) do
      Query.references(state, kind)
    end
  end
end
