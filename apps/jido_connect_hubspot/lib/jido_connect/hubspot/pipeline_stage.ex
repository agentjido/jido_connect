defmodule Jido.Connect.HubSpot.PipelineStage do
  @moduledoc "Normalized HubSpot CRM pipeline stage."

  @schema Zoi.struct(
            __MODULE__,
            %{
              stage_id: Zoi.string(),
              label: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              display_order: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              probability: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              archived?: Zoi.boolean() |> Zoi.default(false),
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
