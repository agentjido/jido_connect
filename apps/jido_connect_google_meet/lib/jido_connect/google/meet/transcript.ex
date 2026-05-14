defmodule Jido.Connect.Google.Meet.Transcript do
  @moduledoc "Normalized Google Meet transcript metadata."

  @schema Zoi.struct(
            __MODULE__,
            %{
              transcript_name: Zoi.string(),
              state: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              start_time: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              end_time: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              docs_destination: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              document_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              export_uri: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
