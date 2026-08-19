defmodule Jido.Connect.Trello.Previews.Support do
  @moduledoc false

  def build(operation, input, fields) do
    Enum.reduce(fields, %{operation: operation}, fn
      {:characters, source, target}, preview ->
        Map.put(preview, target, character_count(Map.get(input, source)))

      field, preview ->
        Map.put(preview, field, Map.get(input, field))
    end)
  end

  defp character_count(value) when is_binary(value), do: String.length(value)
  defp character_count(_value), do: 0
end
