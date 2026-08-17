defmodule Jido.Connect.Things.Handlers.Actions.ListTags do
  @moduledoc false

  alias Jido.Connect.Things.Handlers.Actions.ReferenceHandler

  def run(_input, runtime), do: ReferenceHandler.run(:tag, runtime)
end
