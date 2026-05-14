defmodule Jido.Connect.AuthProfile do
  @moduledoc "Supported provider authorization profile."

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.atom(),
              kind:
                Zoi.enum([
                  :oauth2,
                  :api_key,
                  :app_installation,
                  :service_account,
                  :domain_delegated_service_account,
                  :none
                ]),
              owner: Zoi.enum([:user, :tenant, :org, :system, :installation, :app_user]),
              subject: Zoi.atom(),
              label: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              authorize_url: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              token_url: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              callback_path: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              token_field: Zoi.atom() |> Zoi.nullish() |> Zoi.optional(),
              refresh_token_field: Zoi.atom() |> Zoi.nullish() |> Zoi.optional(),
              setup: Zoi.atom() |> Zoi.nullish() |> Zoi.optional(),
              scopes: Zoi.list(Zoi.string()) |> Zoi.default([]),
              default_scopes: Zoi.list(Zoi.string()) |> Zoi.default([]),
              optional_scopes: Zoi.list(Zoi.string()) |> Zoi.default([]),
              credential_fields: Zoi.list(Zoi.atom()) |> Zoi.default([]),
              lease_fields: Zoi.list(Zoi.atom()) |> Zoi.default([]),
              fields: Zoi.list(Zoi.atom()) |> Zoi.default([]),
              pkce?: Zoi.boolean() |> Zoi.default(false),
              refresh?: Zoi.boolean() |> Zoi.default(false),
              revoke?: Zoi.boolean() |> Zoi.default(false),
              default?: Zoi.boolean() |> Zoi.default(false),
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
