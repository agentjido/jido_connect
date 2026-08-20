defmodule Jido.Connect.Confluence.Previews.Support do
  @moduledoc false

  def character_count(value) when is_binary(value), do: String.length(value)
  def character_count(_value), do: 0
end
