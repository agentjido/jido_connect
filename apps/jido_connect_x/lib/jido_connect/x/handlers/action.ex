defmodule Jido.Connect.X.Handlers.Action do
  @moduledoc false

  def run(input, %{action: %{id: action_id}} = runtime) do
    Jido.Connect.X.RuntimeAdapter.execute(action_id, input, runtime)
  end
end
