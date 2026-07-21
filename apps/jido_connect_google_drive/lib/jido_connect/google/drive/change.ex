defmodule Jido.Connect.Google.Drive.Change do
  @moduledoc "Normalized Google Drive change metadata."

  @schema Zoi.struct(
            __MODULE__,
            %{
              file_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              file: Jido.Connect.Google.Drive.File.schema() |> Zoi.nullish() |> Zoi.optional(),
              removed?: Zoi.boolean() |> Zoi.default(false),
              time: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              drive_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              change_type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
