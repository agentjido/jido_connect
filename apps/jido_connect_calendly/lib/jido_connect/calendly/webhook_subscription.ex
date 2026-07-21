defmodule Jido.Connect.Calendly.WebhookSubscription do
  @moduledoc "Normalized Calendly webhook subscription."

  @schema Zoi.struct(
            __MODULE__,
            %{
              uri: Zoi.string(),
              callback_url: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              scope: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              organization_uri: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              user_uri: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              events: Zoi.list(Zoi.string()) |> Zoi.default([]),
              state: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
