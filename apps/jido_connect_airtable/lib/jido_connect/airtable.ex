defmodule Jido.Connect.Airtable do
  @moduledoc """
  Airtable integration authored with the `Jido.Connect` Spark DSL.

  This module is the provider declaration. Action fragments are added as the
  Airtable surface is implemented.

  ## Auth Profiles

  The provider supports two authentication profiles:

  - **Personal Access Token** (`:personal_access_token`): Airtable PAT passed
    as a Bearer token. Recommended for server-to-server integrations,
    development, and CI.

  - **OAuth2** (`:oauth2_user`): Standard OAuth2 authorization code flow with
    PKCE. Grants scoped access on behalf of an Airtable user.

  ## Airtable Scopes

  The provider declares Airtable API scopes for data and schema access:

  - `data.records:read` / `data.records:write`
  - `schema.bases:read` / `schema.bases:write`
  - `webhook:manage`
  """

  use Jido.Connect,
    fragments: [
      Jido.Connect.Airtable.Actions.Bases,
      Jido.Connect.Airtable.Actions.Records
    ]

  defdelegate catalog_packs, to: Jido.Connect.Airtable.CatalogPacks, as: :all

  integration do
    id(:airtable)
    name("Airtable")
    description("Airtable bases, tables, and records.")
    category(:data)
    docs(["https://airtable.com/developers/web/api/introduction"])
  end

  catalog do
    package(:jido_connect_airtable)
    status(:experimental)
    tags([:airtable, :database, :records, :bases])
  end

  auth do
    api_key :personal_access_token do
      default?(true)
      owner(:app_user)
      subject(:user)
      label("Airtable personal access token")
      setup(:api_key_bearer_token)
      credential_fields([:api_key])
      lease_fields([:api_key])

      scopes([
        "data.records:read",
        "data.records:write",
        "schema.bases:read",
        "schema.bases:write",
        "webhook:manage"
      ])

      default_scopes([
        "data.records:read",
        "schema.bases:read"
      ])
    end

    oauth2 :oauth2_user do
      default?(false)
      owner(:app_user)
      subject(:user)
      label("Airtable OAuth user")
      authorize_url("https://airtable.com/oauth2/v1/authorize")
      token_url("https://airtable.com/oauth2/v1/token")
      callback_path("/integrations/airtable/oauth/callback")
      token_field(:access_token)
      refresh_token_field(:refresh_token)
      setup(:oauth2_authorization_code)
      credential_fields([:access_token, :refresh_token])
      lease_fields([:access_token])

      scopes([
        "data.records:read",
        "data.records:write",
        "schema.bases:read",
        "schema.bases:write",
        "webhook:manage"
      ])

      default_scopes([
        "data.records:read",
        "schema.bases:read"
      ])

      optional_scopes([
        "data.records:write",
        "schema.bases:write",
        "webhook:manage"
      ])

      pkce?(true)
      refresh?(true)
    end
  end
end
