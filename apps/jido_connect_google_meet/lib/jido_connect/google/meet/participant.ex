defmodule Jido.Connect.Google.Meet.Participant do
  @moduledoc "Normalized Google Meet conference participant metadata."

  @schema Zoi.struct(
            __MODULE__,
            %{
              participant_name: Zoi.string(),
              user_type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              user: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              display_name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              signed_in_user: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              anonymous_user: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              phone_user: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              earliest_start_time: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              latest_end_time: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
