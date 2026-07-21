defmodule Jido.Connect.Google.Forms.Watch do
  @moduledoc "Normalized Google Forms push notification watch metadata."

  @schema Zoi.struct(
            __MODULE__,
            %{
              watch_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              target_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              state: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              event_type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              error_type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              create_time: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
