defmodule Jido.Connect.Zendesk.Comment do
  @moduledoc "Normalized Zendesk ticket comment."

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.integer(),
              body: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              html_body: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              plain_body: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              author_id: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              public: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              ticket_id: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              via: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              zendesk_metadata: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              attachments: Zoi.list(Zoi.map()) |> Zoi.default([]),
              created_at: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
