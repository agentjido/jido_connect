defmodule Jido.Connect.Things.Input do
  @moduledoc false

  alias Jido.Connect.Error

  @schemas %{
    "things.todo.create" =>
      Zoi.object(
        %{
          title: Zoi.string(min_length: 1, max_length: 2_000),
          notes: Zoi.string(max_length: 100_000) |> Zoi.optional()
        },
        coerce: true,
        unrecognized_keys: :error
      ),
    "things.todo.update" =>
      Zoi.object(
        %{
          id: Zoi.string(min_length: 1, max_length: 32),
          expected_modified_at: Zoi.string(min_length: 1, max_length: 64),
          title: Zoi.string(min_length: 1, max_length: 2_000) |> Zoi.optional(),
          notes: Zoi.string(max_length: 100_000) |> Zoi.optional()
        },
        coerce: true,
        unrecognized_keys: :error
      )
  }

  def parse(action_id, input) when is_map_key(@schemas, action_id) and is_map(input) do
    with {:ok, normalized} <- normalize_keys(input),
         {:ok, parsed} <- parse_schema(Map.fetch!(@schemas, action_id), normalized),
         :ok <- validate_relation(action_id, parsed),
         {:ok, parsed} <- normalize_expected_modified_at(action_id, parsed) do
      {:ok, parsed}
    end
  end

  def parse(action_id, _input) do
    {:error,
     Error.validation("Things action input is invalid",
       reason: :invalid_input,
       subject: action_id
     )}
  end

  defp normalize_keys(input) do
    Enum.reduce_while(input, {:ok, %{}}, fn {key, value}, {:ok, normalized} ->
      case normalize_key(key) do
        {:ok, normalized_key} when is_map_key(normalized, normalized_key) ->
          {:halt, validation_error(:duplicate_field, normalized_key)}

        {:ok, normalized_key} ->
          {:cont, {:ok, Map.put(normalized, normalized_key, value)}}

        :error ->
          {:halt, validation_error(:unknown_field, key)}
      end
    end)
  end

  defp normalize_key(key) when key in [:id, :expected_modified_at, :title, :notes],
    do: {:ok, key}

  defp normalize_key("id"), do: {:ok, :id}
  defp normalize_key("expected_modified_at"), do: {:ok, :expected_modified_at}
  defp normalize_key("title"), do: {:ok, :title}
  defp normalize_key("notes"), do: {:ok, :notes}
  defp normalize_key(_key), do: :error

  defp parse_schema(schema, input) do
    case Zoi.parse(schema, input) do
      {:ok, parsed} -> {:ok, parsed}
      {:error, errors} -> validation_error(:invalid_input, errors)
    end
  end

  defp validate_relation("things.todo.update", input) do
    if Map.has_key?(input, :title) or Map.has_key?(input, :notes) do
      :ok
    else
      validation_error(:no_changes, :changes)
    end
  end

  defp validate_relation("things.todo.create", _input), do: :ok

  defp normalize_expected_modified_at("things.todo.create", input), do: {:ok, input}

  defp normalize_expected_modified_at("things.todo.update", input) do
    case DateTime.from_iso8601(input.expected_modified_at) do
      {:ok, datetime, 0} ->
        {:ok, Map.put(input, :expected_modified_at, DateTime.to_iso8601(datetime))}

      _other ->
        validation_error(:invalid_datetime, :expected_modified_at)
    end
  end

  defp validation_error(reason, subject) do
    {:error,
     Error.validation("Things action input is invalid",
       reason: reason,
       subject: subject
     )}
  end
end
