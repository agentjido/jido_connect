defmodule Jido.Connect.Asana.Pagination do
  @moduledoc "Normalized Asana API pagination cursor."

  @schema Zoi.struct(
            __MODULE__,
            %{
              offset: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              path: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              uri: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              has_next: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
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
