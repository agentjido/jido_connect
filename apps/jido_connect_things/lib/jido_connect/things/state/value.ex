defmodule Jido.Connect.Things.State.Value do
  @moduledoc false

  @maximum_identifier_count 1_000

  def field({attrs, issues}, payload, wire_key, attr_key, decoder, opts \\ []) do
    case Map.fetch(payload, wire_key) do
      :error ->
        {attrs, issues}

      {:ok, nil} ->
        clear(attrs, issues, wire_key, attr_key, opts)

      {:ok, value} ->
        case decoder.(value) do
          {:ok, decoded} -> {Map.put(attrs, attr_key, decoded), issues}
          :error -> {attrs, [issue(wire_key, :invalid_value) | issues]}
        end
    end
  end

  def string(value) when is_binary(value), do: {:ok, value}
  def string(_value), do: :error

  def boolean(value) when is_boolean(value), do: {:ok, value}
  def boolean(_value), do: :error

  def integer(value) when is_integer(value), do: {:ok, value}
  def integer(_value), do: :error

  def evening(0), do: {:ok, false}
  def evening(1), do: {:ok, true}
  def evening(_value), do: :error

  def enum(values) when is_map(values) do
    fn value ->
      case Map.fetch(values, value) do
        {:ok, decoded} -> {:ok, decoded}
        :error -> :error
      end
    end
  end

  def timestamp(value) when is_integer(value) do
    normalize_timestamp(DateTime.from_unix(value))
  end

  def timestamp(value) when is_float(value) do
    value
    |> Kernel.*(1_000_000)
    |> round()
    |> DateTime.from_unix(:microsecond)
    |> normalize_timestamp()
  end

  def timestamp(_value), do: :error

  def identifiers(value) when is_list(value) and length(value) <= @maximum_identifier_count do
    if Enum.all?(value, &valid_identifier_value?/1) and length(value) == length(Enum.uniq(value)) do
      {:ok, value}
    else
      :error
    end
  end

  def identifiers(_value), do: :error

  def any(value), do: {:ok, value}

  def issue(field, reason), do: %{field: field, reason: reason}

  defp clear(attrs, issues, _wire_key, attr_key, opts) do
    case Keyword.fetch(opts, :clear) do
      {:ok, value} -> {Map.put(attrs, attr_key, value), issues}
      :error -> {attrs, issues}
    end
  end

  defp normalize_timestamp({:ok, %DateTime{} = value}), do: {:ok, value}
  defp normalize_timestamp(_value), do: :error

  defp valid_identifier_value?(value) when is_binary(value) do
    match?(:ok, Jido.Connect.Things.Identifier.validate(value))
  end

  defp valid_identifier_value?(_value), do: false
end
