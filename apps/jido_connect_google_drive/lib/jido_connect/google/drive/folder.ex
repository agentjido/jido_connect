defmodule Jido.Connect.Google.Drive.Folder do
  @moduledoc "Normalized Google Drive folder metadata."

  @schema Zoi.struct(
            __MODULE__,
            %{
              folder_id: Zoi.string(),
              name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              web_view_link: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              created_time: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              modified_time: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              parents: Zoi.list(Zoi.string()) |> Zoi.default([]),
              permissions:
                Zoi.list(Jido.Connect.Google.Drive.Permission.schema()) |> Zoi.default([]),
              trashed?: Zoi.boolean() |> Zoi.default(false),
              shared?: Zoi.boolean() |> Zoi.default(false),
              drive_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
