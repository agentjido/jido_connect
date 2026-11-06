# Changelog

## Unreleased

- Add a shared live smoke test convention in `docs/live_smoke_tests.md`:
  `:live_smoke` tagging and exclusion, credentials from environment variables,
  sanitized recordings of provider responses as `Req.Test` fixtures, and
  captured Slack and Jira deliveries from a demo host capture mode.
- Add `Jido.Connect.Sanitizer.sensitive_key?/1`.
- Add MCP client resources, templates, prompts, completion, ping, and status.
- Add authorized modern and legacy notification sessions with lease checks,
  subscriber monitoring, stream cleanup, and sanitized events.
- Preserve list cursors and search later tool pages during schema checks.
- Integrate SharePoint on the Action v3 compatibility line.
- Use Hex releases for Jido 3, Jido Action 3, Jido Signal 3, and ExMCP 1.5.
- Build the standalone core Hex package with no Git dependency.
- Remove the resolved Cowlib 43971 audit exception. Accept the two remaining
  won't-fix encoder findings as exact, reviewed exceptions for the client path.

- Add the experimental `jido_connect_things` package for guarded Things Cloud
  Inbox list, create, and update actions.
- Add the experimental `jido_connect_tempo` package with Tempo API token and
  OAuth profiles, OAuth helpers, the connection contract, a Bearer transport
  with an origin guard, bounded pagination and the scope resolver.
- Add the Tempo read action `tempo.worklogs.list_own` for the connected
  account's worklogs in an inclusive date range, and the read-only Tempo
  catalog pack `:tempo_reader`.
- Add the Tempo read action `tempo.period.bookability.get` for the connected
  account's approval evidence of every period in an inclusive date range,
  with closure evidence `:unknown` and a derived state, and the read-only
  Tempo catalog pack `:tempo_period_lookup`.
- Add the confirmation-gated Tempo write action `tempo.worklog.create` for
  one own worklog, sent once as `POST /4/worklogs` and never retried, and
  the Tempo catalog pack `:tempo_writer`.
- Add the Tempo read actions `tempo.work_attribute.list` for the work
  attributes of a site and their value contracts, and
  `tempo.account.list_for_project` for the account candidates of a Jira
  project, and the read-only Tempo catalog pack `:tempo_booking_lookup`.
- Add the `:transform` option of `LiveSmoke.record/4`, which leaves out or
  neutralizes data of other users that a shared test account returns,
  before the sanitizer and its leak guard run. A fixture whose body it
  changed carries `"transformed": true`.

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
