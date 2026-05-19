defmodule Jido.Connect.Asana.CustomField do
  @moduledoc "Normalized Asana custom field definition."

  @schema Zoi.struct(
            __MODULE__,
            %{
              gid: Zoi.string(),
              name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              resource_type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              resource_subtype: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              description: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              enabled: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              precision: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              enum_options: Zoi.list(Zoi.map()) |> Zoi.nullish() |> Zoi.optional(),
              enum_value: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              number_value: Zoi.number() |> Zoi.nullish() |> Zoi.optional(),
              text_value: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              multi_enum_values: Zoi.list(Zoi.map()) |> Zoi.nullish() |> Zoi.optional(),
              workspace_gid: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              created_at: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              metadata: Zoi.map() |> Zoi.default(%{})
            },
            coerce: true
          )

  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  def schema, do: @schema
  def new!(attrs), do: Zoi.parse!(@schema, attrs)
  def new(attrs), do: Zoi.parse(@schema, attrs)
end
