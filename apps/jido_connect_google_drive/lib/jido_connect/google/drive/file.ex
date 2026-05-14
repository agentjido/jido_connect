defmodule Jido.Connect.Google.Drive.File do
  @moduledoc "Normalized Google Drive file metadata."

  @schema Zoi.struct(
            __MODULE__,
            %{
              file_id: Zoi.string(),
              name: Zoi.string(),
              mime_type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              description: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              web_view_link: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              web_content_link: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              icon_link: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              thumbnail_link: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              size: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              md5_checksum: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              created_time: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              modified_time: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              parents: Zoi.list(Zoi.string()) |> Zoi.default([]),
              owners: Zoi.list(Zoi.map()) |> Zoi.default([]),
              shared?: Zoi.boolean() |> Zoi.default(false),
              trashed?: Zoi.boolean() |> Zoi.default(false),
              starred?: Zoi.boolean() |> Zoi.default(false),
              drive_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              permissions: Zoi.list(Zoi.map()) |> Zoi.default([]),
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
