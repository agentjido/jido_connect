defmodule Jido.Connect.Airtable.Attachment do
  @moduledoc "Normalized Airtable attachment."

  @schema Zoi.struct(
            __MODULE__,
            %{
              attachment_id: Zoi.string(),
              filename: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              mime_type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              size: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              url: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
