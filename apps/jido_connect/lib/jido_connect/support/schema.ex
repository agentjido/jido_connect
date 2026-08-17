defmodule Jido.Connect.Schema do
  @moduledoc false

  alias Jido.Connect.{Error, Field}

  @doc false
  def zoi_schema_from_fields(fields) when is_list(fields) do
    fields
    |> Enum.map(fn %Field{} = field ->
      {field.name, zoi_field_schema(field)}
    end)
    |> Map.new()
    |> Zoi.object(coerce: true, unrecognized_keys: :error)
  end

  defp zoi_field_schema(%Field{} = field) do
    field.type
    |> zoi_type()
    |> maybe_enum(field.enum)
    |> maybe_minimum(field)
    |> maybe_maximum(field)
    |> maybe_min_length(field)
    |> maybe_max_length(field)
    |> maybe_default(field)
    |> maybe_optional(field)
  end

  defp zoi_type(:string), do: Zoi.string()
  defp zoi_type(:integer), do: Zoi.integer()
  defp zoi_type(:number), do: Zoi.number()
  defp zoi_type(:boolean), do: Zoi.boolean()
  defp zoi_type(:map), do: Zoi.map()
  defp zoi_type(:any), do: Zoi.any()
  defp zoi_type({:array, type}), do: Zoi.list(zoi_type(type))

  defp zoi_type(type) do
    raise Error.validation("Unsupported integration field type",
            reason: :unsupported_field_type,
            subject: type
          )
  end

  defp maybe_enum(schema, nil), do: schema
  defp maybe_enum(_schema, values), do: Zoi.enum(values)

  defp maybe_minimum(schema, %Field{minimum: nil}), do: schema

  defp maybe_minimum(schema, %Field{type: type, minimum: minimum})
       when type in [:integer, :number],
       do: Zoi.min(schema, minimum)

  defp maybe_minimum(_schema, %Field{} = field), do: invalid_constraint(field, :minimum)

  defp maybe_maximum(schema, %Field{maximum: nil}), do: schema

  defp maybe_maximum(schema, %Field{type: type, maximum: maximum})
       when type in [:integer, :number],
       do: Zoi.max(schema, maximum)

  defp maybe_maximum(_schema, %Field{} = field), do: invalid_constraint(field, :maximum)

  defp maybe_min_length(schema, %Field{min_length: nil}), do: schema

  defp maybe_min_length(schema, %Field{type: type, min_length: min_length})
       when type == :string or (is_tuple(type) and elem(type, 0) == :array),
       do: Zoi.min(schema, min_length)

  defp maybe_min_length(_schema, %Field{} = field), do: invalid_constraint(field, :min_length)

  defp maybe_max_length(schema, %Field{max_length: nil}), do: schema

  defp maybe_max_length(schema, %Field{type: type, max_length: max_length})
       when type == :string or (is_tuple(type) and elem(type, 0) == :array),
       do: Zoi.max(schema, max_length)

  defp maybe_max_length(_schema, %Field{} = field), do: invalid_constraint(field, :max_length)

  defp maybe_default(schema, %Field{default: nil}), do: schema
  defp maybe_default(schema, %Field{default: default}), do: Zoi.default(schema, default)

  defp maybe_optional(schema, %Field{required?: true}), do: schema
  defp maybe_optional(schema, %Field{}), do: Zoi.optional(schema)

  defp invalid_constraint(%Field{} = field, constraint) do
    raise Error.validation("Field constraint does not match field type",
            reason: :invalid_field_constraint,
            subject: field.name,
            details: %{constraint: constraint, type: field.type}
          )
  end

  @doc false
  @spec to_json_schema(Zoi.schema()) :: map()
  def to_json_schema(schema) do
    schema
    |> Zoi.to_json_schema()
    |> json_safe()
  end

  @doc false
  @spec strict_object?(map()) :: boolean()
  def strict_object?(json_schema) when is_map(json_schema) do
    Map.get(json_schema, "type") == "object" and
      Map.get(json_schema, "additionalProperties") == false
  end

  @doc false
  @spec digest(term()) :: String.t()
  def digest(value) do
    value
    |> canonical_json()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp canonical_json(map) when is_map(map) do
    entries =
      map
      |> Enum.map(fn {key, value} -> {to_string(key), value} end)
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.map_join(",", fn {key, value} ->
        Jason.encode!(key) <> ":" <> canonical_json(value)
      end)

    "{" <> entries <> "}"
  end

  defp canonical_json(list) when is_list(list) do
    "[" <> Enum.map_join(list, ",", &canonical_json/1) <> "]"
  end

  defp canonical_json(value), do: Jason.encode!(value)

  defp json_safe(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {to_string(key), json_safe(value)} end)
  end

  defp json_safe(list) when is_list(list), do: Enum.map(list, &json_safe/1)

  defp json_safe(value) when is_atom(value) and value not in [true, false, nil],
    do: Atom.to_string(value)

  defp json_safe(value), do: value
end
