defmodule Jido.Connect.MicrosoftSharepoint.Column do
  @moduledoc "Normalized Microsoft Graph SharePoint `columnDefinition` resource."

  @schema Zoi.struct(
            __MODULE__,
            %{
              column_id: Zoi.string(),
              name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              display_name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              description: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              column_type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              settings: Zoi.map() |> Zoi.default(%{}),
              required: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              read_only: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              hidden: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              indexed: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              enforce_unique_values: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
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
