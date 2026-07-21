# Changelog

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
