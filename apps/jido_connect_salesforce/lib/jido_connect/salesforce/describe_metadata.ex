defmodule Jido.Connect.Salesforce.DescribeMetadata do
  @moduledoc "Normalized Salesforce SObject describe metadata."

  @schema Zoi.struct(
            __MODULE__,
            %{
              name: Zoi.string(),
              label: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              label_plural: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              key_prefix: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              createable: Zoi.boolean() |> Zoi.default(false),
              updateable: Zoi.boolean() |> Zoi.default(false),
              deletable: Zoi.boolean() |> Zoi.default(false),
              queryable: Zoi.boolean() |> Zoi.default(false),
              searchable: Zoi.boolean() |> Zoi.default(false),
              fields: Zoi.list(Zoi.map()) |> Zoi.default([]),
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
