defmodule Jido.Connect.Things.Handlers.Actions.ListHeadings do
  @moduledoc false

  alias Jido.Connect.Things.Handlers.Actions.ReferenceHandler

  def run(_input, runtime), do: ReferenceHandler.run(:heading, runtime)
end
