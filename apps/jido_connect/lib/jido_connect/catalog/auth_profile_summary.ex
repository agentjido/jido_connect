defmodule Jido.Connect.Catalog.AuthProfileSummary do
  @moduledoc "Catalog-facing auth profile metadata."

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.atom(),
              kind: Zoi.atom(),
              label: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              owner: Zoi.atom(),
              subject: Zoi.atom(),
              setup: Zoi.atom() |> Zoi.nullish() |> Zoi.optional(),
              default?: Zoi.boolean() |> Zoi.default(false),
              scopes: Zoi.list(Zoi.string()) |> Zoi.default([]),
              default_scopes: Zoi.list(Zoi.string()) |> Zoi.default([]),
              optional_scopes: Zoi.list(Zoi.string()) |> Zoi.default([]),
              credential_fields: Zoi.list(Zoi.atom()) |> Zoi.default([]),
              lease_fields: Zoi.list(Zoi.atom()) |> Zoi.default([])
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
