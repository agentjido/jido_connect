defmodule Jido.Connect.Jira.FieldSchema do
  @moduledoc "Normalized Jira field schema entry."

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.string(),
              name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              key: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              custom: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              orderable: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              navigable: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              searchable: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              clause_names: Zoi.list(Zoi.string()) |> Zoi.default([]),
              schema: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
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
