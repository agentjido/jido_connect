defmodule Jido.Connect.Google.Drive.SharedDrive do
  @moduledoc "Normalized Google Drive shared-drive metadata."

  @schema Zoi.struct(
            __MODULE__,
            %{
              shared_drive_id: Zoi.string(),
              name: Zoi.string(),
              kind: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              color_rgb: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              theme_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              background_image_link: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              background_image_file: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              created_time: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              hidden?: Zoi.boolean() |> Zoi.default(false),
              capabilities: Zoi.map() |> Zoi.default(%{}),
              restrictions: Zoi.map() |> Zoi.default(%{}),
              org_unit_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
