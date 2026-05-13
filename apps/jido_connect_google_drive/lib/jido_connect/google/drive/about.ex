defmodule Jido.Connect.Google.Drive.About do
  @moduledoc "Normalized Google Drive about metadata."

  @schema Zoi.struct(
            __MODULE__,
            %{
              user: Zoi.map() |> Zoi.default(%{}),
              storage_quota: Zoi.map() |> Zoi.default(%{}),
              import_formats: Zoi.map() |> Zoi.default(%{}),
              export_formats: Zoi.map() |> Zoi.default(%{}),
              max_upload_size: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              app_installed?: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              folder_color_palette: Zoi.list(Zoi.string()) |> Zoi.default([]),
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
