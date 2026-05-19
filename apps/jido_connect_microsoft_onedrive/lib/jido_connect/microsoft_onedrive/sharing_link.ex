defmodule Jido.Connect.MicrosoftOnedrive.SharingLink do
  @moduledoc "Normalized Microsoft Graph `sharingLink` facet metadata."

  @schema Zoi.struct(
            __MODULE__,
            %{
              link: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              web_html: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              application: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              prevents_download: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
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
