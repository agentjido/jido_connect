defmodule Jido.Connect.Intercom.Conversation do
  @moduledoc "Normalized Intercom conversation."

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.string(),
              workspace_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              created_at: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              updated_at: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              waiting_since: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              snoozed_until: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              title: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              state: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              open: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              read: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              priority: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              source: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              contacts: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              teammates: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              admin_assignee_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              team_assignee_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              tags: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              conversation_parts: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              statistics: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              custom_attributes: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
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
