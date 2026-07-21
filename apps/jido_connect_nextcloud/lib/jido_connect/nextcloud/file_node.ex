defmodule Jido.Connect.Nextcloud.FileNode do
  @moduledoc "Normalized Nextcloud WebDAV file or folder metadata."

  @schema Zoi.struct(
            __MODULE__,
            %{
              path: Zoi.string(),
              name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              file_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              type: Zoi.enum([:file, :folder, :unknown]) |> Zoi.default(:unknown),
              content_type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              size: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              etag: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              last_modified: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              permissions: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              owner_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              owner_display_name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              favorite?: Zoi.boolean() |> Zoi.default(false),
              share_types: Zoi.list(Zoi.integer()) |> Zoi.default([]),
              share_permissions: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              has_preview?: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              note: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
