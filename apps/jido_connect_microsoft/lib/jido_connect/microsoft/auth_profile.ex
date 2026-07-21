defmodule Jido.Connect.Microsoft.AuthProfile do
  @moduledoc """
  Microsoft auth profile metadata used by product connectors.

  This struct is intentionally separate from `Jido.Connect.AuthProfile` because
  the shared Microsoft foundation needs to describe auth modes before every mode
  is represented in the public provider DSL.
  """

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.atom(),
              kind: Zoi.enum([:oauth2]),
              owner: Zoi.enum([:user, :tenant, :org, :system, :app_user]),
              subject: Zoi.atom(),
              label: Zoi.string(),
              setup: Zoi.atom(),
              token_field: Zoi.atom() |> Zoi.default(:access_token),
              refresh_token_field: Zoi.atom() |> Zoi.nullish() |> Zoi.optional(),
              credential_fields: Zoi.list(Zoi.atom()) |> Zoi.default([]),
              lease_fields: Zoi.list(Zoi.atom()) |> Zoi.default([:access_token]),
              scopes: Zoi.list(Zoi.string()) |> Zoi.default([]),
              default_scopes: Zoi.list(Zoi.string()) |> Zoi.default([]),
              optional_scopes: Zoi.list(Zoi.string()) |> Zoi.default([]),
              default?: Zoi.boolean() |> Zoi.default(false),
              implemented?: Zoi.boolean() |> Zoi.default(true),
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
