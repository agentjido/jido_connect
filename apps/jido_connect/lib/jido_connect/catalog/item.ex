defmodule Jido.Connect.Catalog.Item do
  @moduledoc """
  Canonical public catalog projection of one Connect operation.

  An item is read-only catalog data. `Jido.Connect.Spec`, `ActionSpec`, and
  `TriggerSpec` remain the execution definitions.
  """

  alias Jido.Connect.{Field, PolicyRequirement}
  alias Jido.Connect.Catalog.AuthProfileSummary

  @schema Zoi.struct(
            __MODULE__,
            %{
              ref: Zoi.string(description: "Stable provider, kind, and operation reference"),
              provider: Zoi.atom(),
              provider_name: Zoi.string(),
              provider_metadata: Zoi.map() |> Zoi.default(%{}),
              category: Zoi.atom() |> Zoi.nullish() |> Zoi.optional(),
              package: Zoi.atom() |> Zoi.nullish() |> Zoi.optional(),
              package_version: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              integration_module: Zoi.module(),
              type: Zoi.enum([:action, :trigger]),
              id: Zoi.string(),
              name: Zoi.atom(),
              label: Zoi.string(),
              description: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              tags: Zoi.list(Zoi.atom()) |> Zoi.default([]),
              module: Zoi.module() |> Zoi.nullish() |> Zoi.optional(),
              resource: Zoi.atom() |> Zoi.nullish() |> Zoi.optional(),
              verb: Zoi.atom() |> Zoi.nullish() |> Zoi.optional(),
              data_classification: Zoi.atom() |> Zoi.nullish() |> Zoi.optional(),
              effect: Zoi.atom() |> Zoi.nullish() |> Zoi.optional(),
              availability: Zoi.atom() |> Zoi.nullish() |> Zoi.optional(),
              auth_profile: Zoi.atom(),
              auth_profiles: Zoi.list(Zoi.atom()) |> Zoi.default([]),
              auth_kinds: Zoi.list(Zoi.atom()) |> Zoi.default([]),
              auth: Zoi.list(AuthProfileSummary.schema()) |> Zoi.default([]),
              policies: Zoi.list(PolicyRequirement.schema()) |> Zoi.default([]),
              host_policy_required?: Zoi.boolean() |> Zoi.default(false),
              scopes: Zoi.list(Zoi.string()) |> Zoi.default([]),
              risk: Zoi.atom() |> Zoi.nullish() |> Zoi.optional(),
              confirmation: Zoi.atom() |> Zoi.nullish() |> Zoi.optional(),
              trigger_kind: Zoi.atom() |> Zoi.nullish() |> Zoi.optional(),
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

  @doc "Returns the stable reference for one provider operation."
  @spec ref(atom() | String.t(), :action | :trigger, String.t()) :: String.t()
  def ref(provider, type, id) when type in [:action, :trigger] and is_binary(id) do
    "#{provider}:#{type}:#{id}"
  end

  @doc "Returns the legacy provider-qualified operation reference."
  @spec legacy_ref(t()) :: String.t()
  def legacy_ref(%__MODULE__{} = item), do: "#{item.provider}.#{item.id}"
end
