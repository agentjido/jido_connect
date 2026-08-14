defmodule Jido.Connect.TriggerSpec do
  @moduledoc "Provider trigger contract for webhook and poll sources."

  alias Jido.Connect.Field

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.string(),
              name: Zoi.atom(),
              kind: Zoi.enum([:webhook, :poll]),
              label: Zoi.string(),
              description: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              tags: Zoi.list(Zoi.atom()) |> Zoi.default([]),
              resource: Zoi.atom() |> Zoi.nullish() |> Zoi.optional(),
              verb: Zoi.atom() |> Zoi.nullish() |> Zoi.optional(),
              data_classification: Zoi.atom() |> Zoi.nullish() |> Zoi.optional(),
              auth_profile: Zoi.atom(),
              auth_profiles: Zoi.list(Zoi.atom()) |> Zoi.default([]),
              policies: Zoi.list(Zoi.atom()) |> Zoi.default([]),
              handler: Zoi.module(),
              config: Zoi.list(Field.schema()) |> Zoi.default([]),
              signal: Zoi.list(Field.schema()) |> Zoi.default([]),
              config_schema: Zoi.any(),
              signal_schema: Zoi.any(),
              scopes: Zoi.list(Zoi.string()) |> Zoi.default([]),
              scope_resolver: Zoi.module() |> Zoi.nullish() |> Zoi.optional(),
              verification: Zoi.map() |> Zoi.default(%{kind: :none}),
              dedupe: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              checkpoint: Zoi.atom() |> Zoi.nullish() |> Zoi.optional(),
              interval_ms: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
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
