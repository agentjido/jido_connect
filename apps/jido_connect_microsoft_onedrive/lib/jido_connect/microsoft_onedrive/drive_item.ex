defmodule Jido.Connect.MicrosoftOnedrive.DriveItem do
  @moduledoc "Normalized Microsoft Graph `driveItem` resource metadata."

  alias Jido.Connect.MicrosoftOnedrive.Permission

  @schema Zoi.struct(
            __MODULE__,
            %{
              item_id: Zoi.string(),
              name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              size: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              web_url: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              created_date_time: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              last_modified_date_time: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              folder: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              file: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              parent_reference: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              created_by: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              last_modified_by: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              thumbnails:
                Zoi.list(Jido.Connect.MicrosoftOnedrive.Thumbnail.schema()) |> Zoi.default([]),
              permissions: Zoi.list(Permission.schema()) |> Zoi.default([]),
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
