defmodule Jido.Connect.Google.Drive.Revision do
  @moduledoc "Normalized Google Drive revision metadata."

  @schema Zoi.struct(
            __MODULE__,
            %{
              revision_id: Zoi.string(),
              mime_type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              kind: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              published?: Zoi.boolean() |> Zoi.default(false),
              keep_forever?: Zoi.boolean() |> Zoi.default(false),
              md5_checksum: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              modified_time: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              publish_auto?: Zoi.boolean() |> Zoi.default(false),
              published_outside_domain?: Zoi.boolean() |> Zoi.default(false),
              published_link: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              size: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              original_filename: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              last_modifying_user: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
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
