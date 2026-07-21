defmodule Jido.Connect.Nextcloud.Sharee do
  @moduledoc "Normalized Nextcloud share recipient metadata."

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.string(),
              label: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              type: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              value: Zoi.map() |> Zoi.default(%{}),
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
