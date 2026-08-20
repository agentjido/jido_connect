defmodule Jido.Connect.Trello.Input.Common do
  @moduledoc false

  alias Jido.Connect.{Data, Error}
  alias Jido.Connect.Trello.Contract

  @ari ~r/^ari:cloud:trello::(board|card|check-item|checklist|label|list)\/workspace\/[0-9a-f]{24}\/[0-9a-f]{24}$/
  @card_url ~r/^https:\/\/trello\.com\/c\/[A-Za-z0-9]+(?:\/[A-Za-z0-9_-]+)?\/?$/

  def strict(input, allowed) when is_map(input) do
    allowed = MapSet.new(Enum.map(allowed, &to_string/1))

    unknown =
      input
      |> Map.keys()
      |> Enum.map(&to_string/1)
      |> Enum.reject(&MapSet.member?(allowed, &1))

    if unknown == [], do: :ok, else: invalid(:unknown_field)
  end

  def strict(_input, _allowed), do: invalid(:input)

  def get(input, key), do: Data.get(input, key)

  def put_present(map, input, key) do
    if has_key?(input, key), do: Map.put(map, key, get(input, key)), else: map
  end

  def has_key?(map, key) when is_map(map) do
    Map.has_key?(map, key) or Map.has_key?(map, Atom.to_string(key))
  end

  def ari(value, kind) when is_binary(value) do
    if String.length(value) <= Contract.ari_max() and Regex.match?(@ari, value) and
         String.contains?(value, "::#{kind}/workspace/") do
      :ok
    else
      invalid(kind)
    end
  end

  def ari(_value, kind), do: invalid(kind)

  def card_locator(value) when is_binary(value) do
    if (Regex.match?(@ari, value) and String.contains?(value, "::card/workspace/")) or
         (String.length(value) <= 2_048 and Regex.match?(@card_url, value)) do
      :ok
    else
      invalid(:id)
    end
  end

  def card_locator(_value), do: invalid(:id)

  def required_string(value, maximum, field) when is_binary(value) do
    if String.trim(value) != "" and String.length(value) <= maximum,
      do: :ok,
      else: invalid(field)
  end

  def required_string(_value, _maximum, field), do: invalid(field)

  def plain_string(value, maximum, field) when is_binary(value) do
    if String.length(value) <= maximum, do: :ok, else: invalid(field)
  end

  def plain_string(_value, _maximum, field), do: invalid(field)

  def optional(nil, _validator), do: :ok
  def optional(value, validator), do: validator.(value)

  def integer(value, minimum, maximum, _field)
      when is_integer(value) and value >= minimum and value <= maximum,
      do: :ok

  def integer(_value, _minimum, _maximum, field), do: invalid(field)

  def boolean(value, _field) when is_boolean(value), do: :ok
  def boolean(_value, field), do: invalid(field)

  def position(value, _field) when value in ["top", "bottom"], do: :ok
  def position(value, _field) when is_number(value) and value >= 0, do: :ok
  def position(_value, field), do: invalid(field)

  def utc_datetime(value, field) when is_binary(value) and byte_size(value) <= 64 do
    case DateTime.from_iso8601(value) do
      {:ok, _date_time, 0} -> :ok
      _other -> invalid(field)
    end
  end

  def utc_datetime(_value, field), do: invalid(field)

  def one_of(value, values, field) do
    if value in values, do: :ok, else: invalid(field)
  end

  def require_present(input, fields) do
    if Enum.any?(fields, &has_key?(input, &1)), do: :ok, else: invalid(:update)
  end

  def validate_present(input, key, value, validator) do
    if has_key?(input, key), do: validator.(value), else: :ok
  end

  def invalid(field) do
    {:error,
     Error.validation("Invalid Trello action input",
       reason: :invalid_trello_input,
       subject: field,
       details: %{field: field}
     )}
  end
end
