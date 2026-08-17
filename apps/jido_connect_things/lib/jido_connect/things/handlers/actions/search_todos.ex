defmodule Jido.Connect.Things.Handlers.Actions.SearchTodos do
  @moduledoc false

  alias Jido.Connect.Things.{Query, ReadBoundary, Runtime}

  def run(input, %{context: context, credential_lease: lease}) when is_map(input) do
    runtime = Runtime.runtime_context(context)

    with {:ok, state} <- ReadBoundary.state(context, lease) do
      Query.search(state, input, today: Map.get(runtime, :today, Date.utc_today()))
    end
  end
end
