defmodule Jido.Connect.Catalog.ToolEntry do
  @moduledoc "Flattened catalog-facing tool metadata with provider context."

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
end
