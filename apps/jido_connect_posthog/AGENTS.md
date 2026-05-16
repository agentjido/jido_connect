# PostHog Connector Guidance

- Keep PostHog-specific DSL, handlers, normalized structs, and tests in this
  package. Shared transport, scope, and pagination helpers belong in
  `jido_connect` core or in a future shared package.
- Keep PostHog REST API concerns in focused client modules under
  `Jido.Connect.PostHog.Client.*`.
- The REST transport boundary lives in `Jido.Connect.PostHog.Client.Transport`.
  All PostHog API traffic flows through it.
- PostHog supports two API key auth profiles:
  - **Project API key** (`:project_api_key`): scoped to a single project, read-only.
  - **Personal API key** (`:personal_api_key`): cross-project access, supports write.
- The host override transport boundary reads `posthog_api_base_url` from
  application env, defaulting to `https://app.posthog.com`. Self-hosted
  deployments override this at runtime or via config.
- Do not log or expose API keys or personal access tokens.
- Keep DSL fragments small and grouped by capability. Prefer separate files for
  events, persons, insights, and future feature flag families.
