defmodule Jido.Connect.Catalog.ToolEntry do
  @moduledoc "Flattened catalog-facing tool metadata with provider context."

  alias Jido.Connect.Catalog.Item

  @schema Zoi.struct(
            __MODULE__,
            %{
              provider: Zoi.atom(),
              provider_name: Zoi.string(),
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
              auth_profile: Zoi.atom(),
              auth_profiles: Zoi.list(Zoi.atom()) |> Zoi.default([]),
              auth_kinds: Zoi.list(Zoi.atom()) |> Zoi.default([]),
              policies: Zoi.list(Zoi.atom()) |> Zoi.default([]),
              scopes: Zoi.list(Zoi.string()) |> Zoi.default([]),
              risk: Zoi.atom() |> Zoi.nullish() |> Zoi.optional(),
              confirmation: Zoi.atom() |> Zoi.nullish() |> Zoi.optional(),
              trigger_kind: Zoi.atom() |> Zoi.nullish() |> Zoi.optional(),
              source: Zoi.atom() |> Zoi.default(:curated)
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
      provider: item.provider,
      provider_name: item.provider_name,
      category: item.category,
      package: item.package,
      package_version: item.package_version,
      integration_module: item.integration_module,
      type: item.type,
      id: item.id,
      name: item.name,
      label: item.label,
      description: item.description,
      tags: item.tags,
      module: item.module,
      resource: item.resource,
      verb: item.verb,
      data_classification: item.data_classification,
      auth_profile: item.auth_profile,
      auth_profiles: item.auth_profiles,
      auth_kinds: item.auth_kinds,
      policies: Enum.map(item.policies, & &1.id),
      scopes: item.scopes,
      risk: item.risk,
      confirmation: item.confirmation,
      trigger_kind: item.trigger_kind,
      source: item.source
    })
  end
end
