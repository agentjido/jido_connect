defmodule Jido.Connect.Confluence.Handlers.Actions.GetSpace do
  @moduledoc false

  alias Jido.Connect.Confluence.Handlers.Actions.Support

  def run(input, runtime) do
    Support.call(runtime, & &1.get_space(input, &2))
  end
end
