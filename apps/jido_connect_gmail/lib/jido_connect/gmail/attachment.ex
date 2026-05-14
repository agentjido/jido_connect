defmodule Jido.Connect.Gmail.Attachment do
  @moduledoc """
  Normalized Gmail message attachment body.

  Gmail returns attachment bytes as base64url-encoded `data`. This struct keeps
  the provider payload encoded and does not attempt to decode arbitrary binary
  content in the connector.
  """

  @schema Zoi.struct(
            __MODULE__,
            %{
              attachment_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              size: Zoi.integer() |> Zoi.default(0),
              data: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
