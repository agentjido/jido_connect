defmodule Jido.Connect.Calendly.ScheduledEvent do
  @moduledoc "Normalized Calendly scheduled event."

  alias Jido.Connect.Calendly.{Cancellation, Invitee}

  @schema Zoi.struct(
            __MODULE__,
            %{
              uri: Zoi.string(),
              name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              status: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              start_time: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              end_time: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              location: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              event_type_uri: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              event_type_name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              organization_uri: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              cancellation: Zoi.struct(Cancellation) |> Zoi.nullish() |> Zoi.optional(),
              invitees_counter: Zoi.map() |> Zoi.default(%{}),
              invitees: Zoi.list(Invitee.schema()) |> Zoi.default([]),
              created_at: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              updated_at: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
