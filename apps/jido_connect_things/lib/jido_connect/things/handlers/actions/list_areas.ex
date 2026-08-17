defmodule Jido.Connect.Things.Handlers.Actions.ListAreas do
  @moduledoc false

  alias Jido.Connect.Things.Handlers.Actions.ReferenceHandler

  def run(_input, runtime), do: ReferenceHandler.run(:area, runtime)
end
