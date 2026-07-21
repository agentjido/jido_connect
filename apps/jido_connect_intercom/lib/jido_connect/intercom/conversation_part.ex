defmodule Jido.Connect.Intercom.ConversationPart do
  @moduledoc "Normalized Intercom conversation part."

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.string(),
              type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              part_type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              body: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              created_at: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              updated_at: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              notified_at: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              assigned_to: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              author: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              attachments: Zoi.list(Zoi.map()) |> Zoi.default([]),
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
