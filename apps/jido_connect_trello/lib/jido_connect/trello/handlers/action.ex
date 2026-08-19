defmodule Jido.Connect.Trello.Handlers.Action do
  @moduledoc false

  def run(input, %{action: %{id: action_id}} = runtime) do
    Jido.Connect.Trello.RuntimeAdapter.execute(action_id, input, runtime)
  end
end
