defmodule Jido.Connect.PostHog do
  @moduledoc """
  PostHog analytics integration authored with the `Jido.Connect` Spark DSL.

  This module is the provider declaration. It compiles into hidden generated
  adapter modules under provider-specific Actions and Plugin namespaces.

  ## Auth Profiles

  The provider supports two authentication profiles:

  - **Project API key** (`:project_api_key`): PostHog project API key sent
    via the `Authorization: Bearer <key>` header. Suitable for read-only
    queries and event capture within a single project.

  - **Personal API key** (`:personal_api_key`): PostHog personal API key sent
    via the `Authorization: Bearer <key>` header. Grants access across
    projects and supports write operations. Recommended for server-to-server
    integrations and CI.

  ## Host Override

  The transport boundary reads `posthog_api_base_url` from application env,
  defaulting to `https://app.posthog.com`. Self-hosted PostHog deployments
  override this at runtime or via config.

  ## PostHog Scopes

  The provider declares PostHog permission scopes:

  - `events:read` / `events:write`
  - `persons:read` / `persons:write`
  - `insights:read`
  - `feature_flags:read` / `feature_flags:write`
  """

  use Jido.Connect,
    fragments: [
      Jido.Connect.PostHog.Actions.Events,
      Jido.Connect.PostHog.Actions.EventCapture,
      Jido.Connect.PostHog.Actions.Persons,
      Jido.Connect.PostHog.Actions.Insights,
      Jido.Connect.PostHog.Actions.Query,
      Jido.Connect.PostHog.Actions.FeatureFlags
    ]

  defdelegate catalog_packs, to: Jido.Connect.PostHog.CatalogPacks, as: :all

  integration do
    id(:posthog)
    name("PostHog")

    description("PostHog product analytics, feature flags, and event tracking.")

    category(:data)
    docs(["https://posthog.com/docs/api"])
  end

  catalog do
    package(:jido_connect_posthog)
    status(:experimental)
    tags([:analytics, :events, :feature_flags, :product_analytics])
  end

  auth do
    api_key :project_api_key do
      default?(true)
      owner(:app_user)
      subject(:project)
      label("PostHog project API key")
      setup :api_key_bearer_token
      credential_fields([:api_key])
      lease_fields([:api_key])

      scopes([
        "events:read",
        "persons:read",
        "insights:read"
      ])

      default_scopes([
        "events:read",
        "persons:read",
        "insights:read"
      ])
    end

    api_key :personal_api_key do
      default?(false)
      owner(:app_user)
      subject(:user)
      label("PostHog personal API key")
      setup :api_key_bearer_token
      credential_fields([:api_key])
      lease_fields([:api_key])

      scopes([
        "events:read",
        "events:write",
        "persons:read",
        "persons:write",
        "insights:read",
        "feature_flags:read",
        "feature_flags:write"
      ])

      default_scopes([
        "events:read",
        "persons:read",
        "insights:read"
      ])
    end
  end
end
