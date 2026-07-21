defmodule Jido.Connect.HubSpot.Deal do
  @moduledoc "Normalized HubSpot CRM deal."

  alias Jido.Connect.HubSpot.PipelineStage

  @schema Zoi.struct(
            __MODULE__,
            %{
              deal_id: Zoi.string(),
              deal_name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              amount: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              deal_stage: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              pipeline: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              pipeline_stage: PipelineStage.schema() |> Zoi.nullish() |> Zoi.optional(),
              close_date: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              deal_currency: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              owner_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              description: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              deal_type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              probability: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              created_at: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              updated_at: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              archived?: Zoi.boolean() |> Zoi.default(false),
              archived_at: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              properties: Zoi.map() |> Zoi.default(%{}),
              associations: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
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
