defmodule Jido.Connect.Jira.Previews.Support do
  @moduledoc false

  def byte_count(value) when is_binary(value), do: byte_size(value)
  def byte_count(_value), do: 0

  def item_count(value) when is_list(value), do: length(value)
  def item_count(_value), do: 0

  def changed_fields(input, excluded \\ []) do
    input
    |> Enum.reject(fn {key, value} -> key in excluded or is_nil(value) end)
    |> Enum.map(fn {key, _value} -> Atom.to_string(key) end)
    |> Enum.sort()
  end
end
