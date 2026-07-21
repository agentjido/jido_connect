defmodule Jido.Connect.HubSpot.Pipeline do
  @moduledoc "Normalized HubSpot CRM pipeline."

  alias Jido.Connect.HubSpot.PipelineStage

  @schema Zoi.struct(
            __MODULE__,
            %{
              pipeline_id: Zoi.string(),
              label: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              display_order: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              archived?: Zoi.boolean() |> Zoi.default(false),
              stages: Zoi.list(PipelineStage.schema()) |> Zoi.default([]),
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
