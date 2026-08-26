# Changelog

## Unreleased

- Add the experimental `jido_connect_things` package for guarded Things Cloud
  Inbox list, create, and update actions.

## 0.9.0 - 2026-08-25

- Make `Jido.Connect.Catalog.Item` the canonical catalog projection and keep
  the previous catalog paths as compatibility adapters.
- Move the narrow MCP tool bridge into core `jido_connect` and replace its
  `jido_mcp` backend with stable ExMCP `1.x`.
- Preserve connection, lease, scope, policy, confirmation, schema-drift, and
  uncertain-write controls for MCP operations.
- Remove the unpublished `jido_connect_mcp` application without a compatibility
  package.
- Prepare core `jido_connect` `0.9.0` as a release candidate. Connector package
  versions remain `0.8.0` until their separate releases.

## 0.8.0 - 2026-07-21

- Expand the umbrella to 36 packages for shared runtimes, inbound webhooks, MCP,
  and service providers.
- Add connectors for Airtable, Asana, Cal.com, Calendly, GitLab, Google
  Workspace, HubSpot, Intercom, Jira, Linear, Microsoft 365, Nextcloud,
  Notion, PostHog, Salesforce, and Zendesk.
- Add catalog discovery, search, descriptions, packs, diagnostics, and generated
  Jido actions, sensors, and plugins.
- Add shared authentication, scope resolution, normalized errors, pagination,
  sanitization, and webhook verification contracts.
- Move all package versions to `0.8.0` and use the canonical
  `agentjido/jido_connect` repository metadata.
- Update direct dependencies, remove obsolete direct dependencies, and resolve
  all known Hex security advisories.
- Add grouped Dependabot updates for Mix, Bun, and GitHub Actions dependencies.
- Rewrite the root README with the full package inventory, architecture, setup,
  usage, security model, and maintenance guidance.

## 0.1.0

- Introduce the `jido_connect` umbrella with separate core, GitHub, Slack, and MCP provider packages.
- Compile Spark DSL integrations into Jido actions, sensors, and plugins.
- Add GitHub OAuth, GitHub App auth, REST client, webhook helpers, and a local Phoenix demo host.
- Add Slack OAuth, Web API actions, signed request verification, and Events API trigger metadata.
- Add an MCP bridge package backed by `jido_mcp`.
- Add catalog discovery, diagnostics, provider self-registration, and release baseline guidance.
