defmodule Jido.Connect.Things.WriteWire.Validation do
  @moduledoc false

  alias Jido.Connect.Error
  alias Jido.Connect.Things.Identifier

  def title(value), do: text(value, :title, 1, 2_000, false)
  def notes(value), do: text(value, :notes, 0, 100_000, true)

  def identifier(value) do
    case Identifier.validate(value) do
      :ok -> {:ok, value}
      {:error, reason} -> validation_error(:id, :unsafe_identifier, %{identifier_reason: reason})
    end
  end

  def timestamp(%DateTime{} = datetime) do
    {:ok, DateTime.to_unix(datetime, :microsecond) / 1_000_000}
  end

  def timestamp(value) when is_integer(value) and value > 0, do: {:ok, value * 1.0}

  def timestamp(value) when is_float(value) and value > 0 do
    case Jason.encode(value) do
      {:ok, _encoded} -> {:ok, value}
      {:error, _error} -> validation_error(:timestamp, :not_finite)
    end
  end

  def timestamp(_value), do: validation_error(:timestamp, :invalid_timestamp)

  def changes(input) when is_map(input) do
    attrs =
      [:title, :notes]
      |> Enum.reduce([], fn key, acc ->
        if Map.has_key?(input, key), do: [{key, Map.get(input, key)} | acc], else: acc
      end)
      |> Enum.reverse()

    if attrs == [] do
      validation_error(:changes, :no_changes)
    else
      {:ok, attrs}
    end
  end

  defp text(value, field, minimum, maximum, multiline?) when is_binary(value) do
    length = String.length(value)

    cond do
      not String.valid?(value) ->
        validation_error(field, :invalid_utf8)

      String.contains?(value, "\0") ->
        validation_error(field, :contains_nul)

      not multiline? and String.contains?(value, ["\r", "\n"]) ->
        validation_error(field, :contains_newline)

      length < minimum ->
        validation_error(field, :too_short, %{minimum: minimum})

      length > maximum ->
        validation_error(field, :too_long, %{maximum: maximum})

      true ->
        {:ok, value}
    end
  end

  defp text(_value, field, _minimum, _maximum, _multiline?),
    do: validation_error(field, :must_be_string)

  defp validation_error(field, reason, details \\ %{}) do
    {:error,
     Error.validation("Things action input is invalid",
       reason: reason,
       subject: field,
       details: Map.put(details, :field, field)
     )}
  end
end
