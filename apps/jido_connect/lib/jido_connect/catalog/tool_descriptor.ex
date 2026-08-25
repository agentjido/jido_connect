defmodule Jido.Connect.Catalog.ToolDescriptor do
  @moduledoc "Schema-rich catalog description for one action or trigger tool."

  alias Jido.Connect.{Field, PolicyRequirement}
  alias Jido.Connect.Catalog.{AuthProfileSummary, Item, ToolEntry}

  @schema Zoi.struct(
            __MODULE__,
            %{
              tool: ToolEntry.schema(),
              provider: Zoi.map(),
              input: Zoi.list(Field.schema()) |> Zoi.default([]),
              output: Zoi.list(Field.schema()) |> Zoi.default([]),
              config: Zoi.list(Field.schema()) |> Zoi.default([]),
              signal: Zoi.list(Field.schema()) |> Zoi.default([]),
              input_json_schema: Zoi.map() |> Zoi.default(%{}),
              output_json_schema: Zoi.map() |> Zoi.default(%{}),
              config_json_schema: Zoi.map() |> Zoi.default(%{}),
              signal_json_schema: Zoi.map() |> Zoi.default(%{}),
              schema_digest: Zoi.string(),
              strict?: Zoi.boolean() |> Zoi.default(true),
              auth: Zoi.list(AuthProfileSummary.schema()) |> Zoi.default([]),
              policies: Zoi.list(PolicyRequirement.schema()) |> Zoi.default([]),
              host_policy_required?: Zoi.boolean() |> Zoi.default(false),
              scopes: Zoi.list(Zoi.string()) |> Zoi.default([]),
              risk: Zoi.atom() |> Zoi.nullish() |> Zoi.optional(),
              confirmation: Zoi.atom() |> Zoi.nullish() |> Zoi.optional(),
              provider_idempotency?: Zoi.boolean() |> Zoi.default(false),
              source: Zoi.atom() |> Zoi.default(:curated),
              pack: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              reviewed_fingerprint: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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

  @doc false
  @spec from_item(Item.t()) :: t()
  def from_item(%Item{} = item) do
    new!(%{
      tool: ToolEntry.from_item(item),
      provider: item.provider_metadata,
      input: item.input,
      output: item.output,
      config: item.config,
      signal: item.signal,
      input_json_schema: item.input_json_schema,
      output_json_schema: item.output_json_schema,
      config_json_schema: item.config_json_schema,
      signal_json_schema: item.signal_json_schema,
      schema_digest: item.schema_digest,
      strict?: item.strict?,
      auth: item.auth,
      policies: item.policies,
      host_policy_required?: item.host_policy_required?,
      scopes: item.scopes,
      risk: item.risk,
      confirmation: item.confirmation,
      provider_idempotency?: item.provider_idempotency?,
      source: item.source,
      pack: item.pack,
      reviewed_fingerprint: item.reviewed_fingerprint,
      metadata: item.metadata
    })
  end
end
