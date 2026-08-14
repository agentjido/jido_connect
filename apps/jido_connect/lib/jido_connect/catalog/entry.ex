defmodule Jido.Connect.Catalog.Entry do
  @moduledoc "Catalog-facing integration metadata."

  alias Jido.Connect.{
    ConnectorCapability,
    NamedSchema,
    PolicyRequirement
  }

  alias Jido.Connect.Catalog.{AuthProfileSummary, Tool}

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.atom(),
              name: Zoi.string(),
              description: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              category: Zoi.atom() |> Zoi.nullish() |> Zoi.optional(),
              package: Zoi.atom() |> Zoi.nullish() |> Zoi.optional(),
              version: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              module: Zoi.module(),
              status: Zoi.atom() |> Zoi.default(:available),
              tags: Zoi.list(Zoi.atom()) |> Zoi.default([]),
              visibility: Zoi.atom() |> Zoi.default(:public),
              docs: Zoi.list(Zoi.string()) |> Zoi.default([]),
              capabilities: Zoi.list(ConnectorCapability.schema()) |> Zoi.default([]),
              policies: Zoi.list(PolicyRequirement.schema()) |> Zoi.default([]),
              schemas: Zoi.list(NamedSchema.schema()) |> Zoi.default([]),
              auth_profiles: Zoi.list(AuthProfileSummary.schema()) |> Zoi.default([]),
              actions: Zoi.list(Tool.schema()) |> Zoi.default([]),
              triggers: Zoi.list(Tool.schema()) |> Zoi.default([]),
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
