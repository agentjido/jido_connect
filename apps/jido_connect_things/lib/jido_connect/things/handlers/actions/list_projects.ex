defmodule Jido.Connect.Things.Handlers.Actions.ListProjects do
  @moduledoc false

  alias Jido.Connect.Things.Handlers.Actions.ReferenceHandler

  def run(_input, runtime), do: ReferenceHandler.run(:project, runtime)
end
