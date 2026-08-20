defmodule Jido.Connect.Confluence.Input.Spaces do
  @moduledoc false

  alias Jido.Connect.{Data, Error}
  alias Jido.Connect.Confluence.Contract

  def validate_get(input) when is_map(input) do
    key = Data.get(input, :key)

    if bounded_non_blank?(key, Contract.maximum_identifier_length()) do
      {:ok, %{key: key}}
    else
      invalid(:key)
    end
  end

  def validate_get(_input), do: invalid(:input)

  defp bounded_non_blank?(value, maximum) do
    is_binary(value) and String.trim(value) != "" and String.length(value) <= maximum
  end

  defp invalid(field) do
    {:error,
     Error.validation("Invalid Confluence space input",
       reason: :invalid_confluence_input,
       subject: field,
       details: %{field: field}
     )}
  end
end
