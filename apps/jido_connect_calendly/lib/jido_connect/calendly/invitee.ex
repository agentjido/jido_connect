defmodule Jido.Connect.Calendly.Invitee do
  @moduledoc "Normalized Calendly event invitee."

  @schema Zoi.struct(
            __MODULE__,
            %{
              uri: Zoi.string(),
              email: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              status: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              timezone: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              event_uri: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              new_invitee_uri: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              old_invitee_uri: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              canceled_by: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              cancellation_reason: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              reschedule_reason: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              reschedule_url: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              cancel_url: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              questions_and_answers: Zoi.list(Zoi.map()) |> Zoi.default([]),
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
