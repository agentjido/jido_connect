defmodule Jido.Connect.Google.Meet.ConferenceRecord do
  @moduledoc "Normalized Google Meet conference record metadata."

  @schema Zoi.struct(
            __MODULE__,
            %{
              conference_record_name: Zoi.string(),
              space: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              start_time: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              end_time: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              expire_time: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
