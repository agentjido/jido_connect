defmodule Jido.Connect.Things.ChecklistItem do
  @moduledoc "Normalized Things checklist item retained by the V1 state reader."

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.string(min_length: 1, max_length: 32),
              entity_version: Zoi.string() |> Zoi.default("ChecklistItem3"),
              task_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              title: Zoi.string(max_length: 2_000) |> Zoi.default(""),
              status: Zoi.enum([:open, :completed, :canceled]) |> Zoi.default(:open),
              stopped_at: Zoi.datetime() |> Zoi.nullish() |> Zoi.optional(),
              position: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              created_at: Zoi.datetime() |> Zoi.nullish() |> Zoi.optional(),
              modified_at: Zoi.datetime() |> Zoi.nullish() |> Zoi.optional(),
              deleted: Zoi.boolean() |> Zoi.default(false),
              state_complete: Zoi.boolean() |> Zoi.default(true),
              last_server_index: Zoi.integer() |> Zoi.default(0),
              unknown_fields: Zoi.map() |> Zoi.default(%{})
            },
            coerce: true,
            unrecognized_keys: :error
          )

  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  def schema, do: @schema
  def new(attrs), do: Zoi.parse(@schema, attrs)
  def new!(attrs), do: Zoi.parse!(@schema, attrs)
end
