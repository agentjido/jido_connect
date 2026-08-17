defmodule Jido.Connect.Things.Input do
  @moduledoc false

  alias Jido.Connect.Error

  @target_fields %{
    id: Zoi.string(min_length: 1, max_length: 32),
    expected_modified_at: Zoi.string(min_length: 1, max_length: 64)
  }

  @target_schema Zoi.object(@target_fields, coerce: true, unrecognized_keys: :error)

  @schemas %{
    "things.todo.create" =>
      Zoi.object(
        %{
          title: Zoi.string(min_length: 1, max_length: 2_000),
          notes: Zoi.string(max_length: 10_000) |> Zoi.optional(),
          schedule: Zoi.string(min_length: 1, max_length: 32) |> Zoi.optional(),
          deadline: Zoi.string(min_length: 10, max_length: 10) |> Zoi.optional(),
          tag_ids: Zoi.list(Zoi.string(min_length: 1, max_length: 32)) |> Zoi.default([]),
          area_id: Zoi.string(min_length: 1, max_length: 32) |> Zoi.optional(),
          project_id: Zoi.string(min_length: 1, max_length: 32) |> Zoi.optional(),
          heading_id: Zoi.string(min_length: 1, max_length: 32) |> Zoi.optional()
        },
        coerce: true,
        unrecognized_keys: :error
      ),
    "things.todo.update" =>
      Zoi.object(
        Map.merge(@target_fields, %{
          title: Zoi.string(min_length: 1, max_length: 2_000) |> Zoi.optional(),
          notes: Zoi.string(max_length: 10_000) |> Zoi.optional()
        }),
        coerce: true,
        unrecognized_keys: :error
      ),
    "things.todo.schedule" =>
      Zoi.object(
        Map.put(@target_fields, :schedule, Zoi.string(min_length: 1, max_length: 32)),
        coerce: true,
        unrecognized_keys: :error
      ),
    "things.todo.deadline.set" =>
      Zoi.object(
        Map.put(@target_fields, :deadline, Zoi.string(min_length: 10, max_length: 10)),
        coerce: true,
        unrecognized_keys: :error
      ),
    "things.todo.deadline.clear" => @target_schema,
    "things.todo.tags.set" =>
      Zoi.object(
        Map.put(
          @target_fields,
          :tag_ids,
          Zoi.list(Zoi.string(min_length: 1, max_length: 32))
        ),
        coerce: true,
        unrecognized_keys: :error
      ),
    "things.todo.move" =>
      Zoi.object(
        Map.merge(@target_fields, %{
          area_id: Zoi.string(min_length: 1, max_length: 32) |> Zoi.optional(),
          project_id: Zoi.string(min_length: 1, max_length: 32) |> Zoi.optional(),
          heading_id: Zoi.string(min_length: 1, max_length: 32) |> Zoi.optional(),
          schedule: Zoi.string(min_length: 1, max_length: 32) |> Zoi.optional()
        }),
        coerce: true,
        unrecognized_keys: :error
      ),
    "things.todo.complete" => @target_schema,
    "things.todo.cancel" => @target_schema,
    "things.todo.reopen" => @target_schema,
    "things.todo.trash" => @target_schema,
    "things.todo.restore" => @target_schema
  }

  @keys [
    :id,
    :expected_modified_at,
    :title,
    :notes,
    :schedule,
    :deadline,
    :tag_ids,
    :area_id,
    :project_id,
    :heading_id
  ]

  def parse(action_id, input) when is_map_key(@schemas, action_id) and is_map(input) do
    with {:ok, normalized} <- normalize_keys(input),
         {:ok, parsed} <- parse_schema(Map.fetch!(@schemas, action_id), normalized),
         :ok <- validate_action(action_id, parsed),
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

  defp normalize_key(key) when key in @keys, do: {:ok, key}

  defp normalize_key(key) when is_binary(key) do
    case Enum.find(@keys, &(Atom.to_string(&1) == key)) do
      nil -> :error
      value -> {:ok, value}
    end
  end

  defp normalize_key(_key), do: :error

  defp parse_schema(schema, input) do
    case Zoi.parse(schema, input) do
      {:ok, parsed} -> {:ok, parsed}
      {:error, errors} -> validation_error(:invalid_input, errors)
    end
  end

  defp validate_action("things.todo.update", input) do
    if Map.has_key?(input, :title) or Map.has_key?(input, :notes),
      do: :ok,
      else: validation_error(:no_changes, :changes)
  end

  defp validate_action("things.todo.create", input), do: validate_dates_and_schedule(input)
  defp validate_action("things.todo.schedule", input), do: validate_schedule(input.schedule)
  defp validate_action("things.todo.move", input), do: validate_optional_schedule(input)

  defp validate_action("things.todo.deadline.set", input),
    do: validate_date(input.deadline, :deadline)

  defp validate_action(_action_id, _input), do: :ok

  defp validate_dates_and_schedule(input) do
    with :ok <- validate_optional_schedule(input) do
      case Map.get(input, :deadline) do
        nil -> :ok
        value -> validate_date(value, :deadline)
      end
    end
  end

  defp validate_optional_schedule(input) do
    case Map.get(input, :schedule) do
      nil -> :ok
      value -> validate_schedule(value)
    end
  end

  defp validate_schedule(value)
       when value in ["inbox", "anytime", "someday", "today", "evening"],
       do: :ok

  defp validate_schedule(value), do: validate_date(value, :schedule)

  defp validate_date(value, field) do
    case Date.from_iso8601(value) do
      {:ok, _date} -> :ok
      {:error, _reason} -> validation_error(:invalid_date, field)
    end
  end

  defp normalize_expected_modified_at("things.todo.create", input), do: {:ok, input}

  defp normalize_expected_modified_at(_action_id, input) do
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
