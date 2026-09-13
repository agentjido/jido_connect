defmodule Jido.Connect.Schema do
  @moduledoc false

  alias Jido.Connect.{Error, Field}

  @doc false
  def zoi_schema_from_fields(fields) when is_list(fields) do
    validate_unique_fields!(fields)

    # Keep enum values for JSON Schema. Zoi.one_of/2 enforces the base type but
    # does not export its allowed values.
    enum_values =
      fields
      |> Enum.filter(&is_list(&1.enum))
      |> Map.new(&{&1.name, {&1.type, &1.enum}})

    fields
    |> Enum.map(fn %Field{} = field ->
      {field.name, zoi_field_schema(field)}
    end)
    |> Map.new()
    |> Zoi.object(
      coerce: true,
      unrecognized_keys: :error,
      metadata: [jido_connect_enum_values: enum_values]
    )
  end

  @doc false
  def validate_unique_fields!(fields) when is_list(fields) do
    Enum.reduce(fields, MapSet.new(), fn %Field{name: name}, seen ->
      if MapSet.member?(seen, name) do
        raise Error.validation("Duplicate field name",
                reason: :duplicate_field_name,
                subject: name
              )
      end

      MapSet.put(seen, name)
    end)

    fields
  end

  defp zoi_field_schema(%Field{} = field) do
    base_schema =
      field
      |> base_field_type()
      |> maybe_minimum(field)
      |> maybe_maximum(field)
      |> maybe_min_length(field)
      |> maybe_max_length(field)

    validate_enum_and_default!(base_schema, field)

    base_schema
    |> maybe_enum(field)
    |> maybe_optional(field)
    |> maybe_default(field)
  end

  defp base_field_type(%Field{type: {:array, element_type}, enum: values} = field)
       when is_list(values) do
    element_schema = zoi_type(element_type)
    Enum.each(values, &validate_field_value!(element_schema, &1, field, :enum))
    Zoi.list(Zoi.one_of(element_schema, values), field_guidance(field))
  end

  defp base_field_type(%Field{type: type} = field), do: zoi_type(type, field_guidance(field))

  defp field_guidance(%Field{} = field) do
    []
    |> maybe_guidance(:description, field.description)
    |> maybe_guidance(:example, field.example)
  end

  defp maybe_guidance(opts, _key, nil), do: opts
  defp maybe_guidance(opts, key, value), do: Keyword.put(opts, key, value)

  defp validate_enum_and_default!(base_schema, %Field{} = field) do
    unless match?({:array, _}, field.type) do
      Enum.each(field.enum || [], &validate_field_value!(base_schema, &1, field, :enum))
    end

    if field.default != nil do
      validate_field_value!(base_schema, field.default, field, :default)

      if field.enum && not match?({:array, _}, field.type) &&
           not Enum.any?(field.enum, &(&1 === field.default)) do
        invalid_field_value!(field, :default)
      end
    end
  end

  defp validate_field_value!(schema, value, field, kind) do
    case Zoi.parse(schema, value) do
      {:ok, ^value} -> :ok
      _ -> invalid_field_value!(field, kind)
    end
  end

  defp invalid_field_value!(field, kind) do
    raise Error.validation("Invalid field #{kind} value",
            reason: :invalid_field_value,
            subject: field.name,
            details: %{kind: kind, type: field.type}
          )
  end

  defp zoi_type(type, opts \\ [])

  defp zoi_type(:string, opts), do: Zoi.string(opts)
  defp zoi_type(:integer, opts), do: Zoi.integer(opts)
  defp zoi_type(:number, opts), do: Zoi.number(opts)
  defp zoi_type(:boolean, opts), do: Zoi.boolean(opts)
  defp zoi_type(:map, opts), do: Zoi.map(opts)
  defp zoi_type(:any, opts), do: Zoi.any(opts)
  defp zoi_type({:array, type}, opts), do: Zoi.list(zoi_type(type), opts)

  defp zoi_type(type, _opts) do
    raise Error.validation("Unsupported integration field type",
            reason: :unsupported_field_type,
            subject: type
          )
  end

  defp maybe_enum(schema, %Field{type: {:array, _}}), do: schema
  defp maybe_enum(schema, %Field{enum: nil}), do: schema
  # Zoi.enum/1 can ignore base limits and export numeric values as strings.
  defp maybe_enum(schema, %Field{enum: values}), do: Zoi.one_of(schema, values)

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
    json_schema = schema |> Zoi.to_json_schema() |> json_safe()
    enum_values = Zoi.metadata(schema)[:jido_connect_enum_values] || %{}

    Enum.reduce(enum_values, json_schema, fn {name, {type, values}}, acc ->
      update_in(acc, ["properties", Atom.to_string(name)], fn property ->
        case type do
          {:array, _} -> update_in(property, ["items"], &Map.put(&1, "enum", json_safe(values)))
          _ -> Map.put(property, "enum", json_safe(values))
        end
      end)
    end)
  end

  @doc false
  @spec to_json_schema(Zoi.schema(), [Field.t()], map()) :: map()
  def to_json_schema(schema, fields, root_overlay \\ %{})
      when is_list(fields) and is_map(root_overlay) do
    schema
    |> to_json_schema()
    |> apply_field_schemas(fields)
    |> Map.merge(json_safe(root_overlay))
  end

  defp apply_field_schemas(schema, fields) do
    properties = Map.get(schema, "properties", %{})

    properties =
      Enum.reduce(fields, properties, fn
        %Field{name: name, json_schema: json_schema} = field, acc when is_map(json_schema) ->
          overlay =
            json_schema
            |> json_safe()
            |> maybe_schema_guidance("description", field.description)
            |> maybe_schema_guidance("example", field.example)

          Map.put(acc, Atom.to_string(name), overlay)

        %Field{}, acc ->
          acc
      end)

    Map.put(schema, "properties", properties)
  end

  defp maybe_schema_guidance(schema, _key, nil), do: schema
  defp maybe_schema_guidance(schema, key, value), do: Map.put_new(schema, key, json_safe(value))

  @doc false
  @spec at_least_one_of([atom() | String.t()]) :: map()
  def at_least_one_of(fields) when is_list(fields) and fields != [] do
    %{
      "anyOf" =>
        Enum.map(fields, fn field ->
          %{"required" => [to_string(field)]}
        end)
    }
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
