defmodule Jido.Connect.Google.Drive.Revision do
  @moduledoc "Normalized Google Drive file revision metadata."

  @schema Zoi.struct(
            __MODULE__,
            %{
              revision_id: Zoi.string(),
              mime_type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              modified_time: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              keep_forever?: Zoi.boolean() |> Zoi.default(false),
              published?: Zoi.boolean() |> Zoi.default(false),
              publish_auto?: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              published_outside_domain?: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              last_modifying_user: Zoi.map() |> Zoi.default(%{}),
              original_filename: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              md5_checksum: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              size: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              export_links: Zoi.map() |> Zoi.default(%{}),
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
