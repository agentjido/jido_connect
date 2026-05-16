defmodule Jido.Connect.Calendly.Cancellation do
  @moduledoc "Normalized Calendly cancellation details."

  @schema Zoi.struct(
            __MODULE__,
            %{
              canceled_by: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              reason: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              invitee_uri: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              event_uri: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              organization_uri: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              canceled_at: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
