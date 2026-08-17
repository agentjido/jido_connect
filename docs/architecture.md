# Architecture

`jido_connect` is a connector factory. The core package owns the shared
contracts and runtime boundary; provider packages normalize provider-specific
details into those contracts.

## Package Layers

The umbrella has three layers:

- `jido_connect` owns the Spark DSL, Zoi-backed contract structs, generated Jido
  adapters, authorization checks, catalog discovery, telemetry, and normalized
  runtime envelopes.
- Provider packages such as `jido_connect_github`, `jido_connect_slack`, and
  `jido_connect_mcp` own provider auth helpers, REST or bridge clients, webhook
  verification, scope resolvers, and handlers.
- `dev/demo` is a local host harness. It owns local callbacks, in-memory
  connections, credential lookup, webhook consoles, and action runners. It is
  not part of the published packages.

## Core Contracts

The base package should stay storage-free and provider-neutral. Its primary
contracts are:

- `Jido.Connect.Spec`, `AuthProfile`, `ActionSpec`, and `TriggerSpec` for the
  compiled integration declaration.
- `Jido.Connect.NamedSchema`, `PolicyRequirement`, and `ConnectorCapability`
  for reusable schemas, host policy intent, and catalog-facing feature
  metadata.
- `Jido.Connect.Connection` and `ConnectionSelector` for durable grant metadata
  and host-owned lookup intent.
- `Jido.Connect.CredentialLease` for short-lived credential material passed to a
  single action, sensor, or bridge call.
- `Jido.Connect.Context` for tenant, actor, connection, and selector data at
  execution time.
- `Jido.Connect.ProviderResponse`, `WebhookDelivery`, and
  `ConnectorCapability` for reusable normalized envelopes.
- `Jido.Connect.Run` and `Event` for host audit surfaces.

Providers should normalize into these structs instead of leaking raw provider
maps into shared APIs.

## Generated Jido Modules

Every `use Jido.Connect` provider compiles thin generated modules:

- `<Provider>.Actions.*`
- `<Provider>.Sensors.*`
- `<Provider>.Plugin`

Generated modules carry projection metadata and delegate to core runtimes. They
do not contain provider business logic, read raw credentials, or become a second
authoring surface.

## Authorization Flow

Action and sensor execution use one shared authorization path:

- resolve a `Context`
- resolve or validate a `Connection`
- require an active `CredentialLease`
- ensure the lease is bound to the connection
- ensure the connection profile is allowed for the operation
- resolve static and dynamic scopes
- execute the provider handler only after those checks pass

Provider packages may supply scope resolvers for input-dependent access rules,
such as Slack conversation types or GitHub App installation permissions.

## DSL Shape

Provider DSL declarations are split by concern:

- `integration` names the provider.
- `catalog` declares package, status, tags, visibility, and capabilities.
- `schemas` declares reusable named field groups.
- `auth` declares OAuth, API key, app installation, and bridge auth profiles.
- `policies` describes host-owned authorization decisions required by tools.
- `actions` and `triggers` declare resource/verb metadata, requirements, schemas,
  handlers, risk, confirmation, and generated Jido module projections.

Provider business logic still belongs in handlers; the DSL is the source of
truth for metadata, runtime contracts, catalog discovery, and generated Jido
adapters.

## Provider Package Shape

A mature provider package should generally include:

- `integration.ex` for the DSL declaration and catalog capability metadata.
- `oauth.ex`, `app_auth.ex`, or equivalent auth helpers.
- `client.ex` for provider HTTP or bridge calls and error normalization.
- `webhook.ex` for signature verification and event normalization.
- `scope_resolver.ex` when scopes depend on inputs, config, or auth profile.
- handler modules under `handlers/` for action and trigger execution.

The base package provides reusable helpers for OAuth, HTTP, webhooks, polling,
catalog discovery, host policy callbacks, sanitization, errors, telemetry, and
credential leases.

## Host Boundary

Hosts own persistence and policy:

- durable connection records
- encrypted credential storage
- OAuth state and callback sessions
- webhook delivery dedupe
- prepared-action approval storage and atomic execution claims
- actor authorization for shared user, tenant, installation, or system grants
- audit storage

`jido_connect` validates the execution boundary and can call a host-supplied
policy callback before provider handlers run, but it intentionally does not ship
storage behaviours, Ecto schemas, migrations, or permission policy.

## Catalog

`Jido.Connect.Catalog` turns provider modules into discoverable entries with
auth profiles, tools, generated modules, tags, resource metadata, policy
requirements, and high-level capabilities. The `catalog` DSL section declares
explicit setup, webhook, bridge, or runtime capabilities while the base package
derives auth, action, and trigger capabilities from the DSL.

Use `Jido.Connect.Catalog.discover/1` for provider-level discovery and
`Jido.Connect.Catalog.tools/1` for a flattened action/trigger catalog across
installed providers.

Provider packages self-register their provider modules through application env
under `:jido_connect_providers`. This means host apps choose the catalog by
choosing dependencies: installing only `jido_connect_github` exposes GitHub
entries, while Slack remains absent unless `jido_connect_slack` is also in the
dependency graph. Hosts can still add private or local providers with
`config :jido_connect, catalog_modules: [...]`.

`discover/1` is intentionally lenient and returns valid entries only.
`discover_with_diagnostics/1` returns both valid entries and structured
diagnostics for modules that fail to load, omit `integration/0`, or raise while
building catalog metadata. Demo apps, CI checks, and admin UIs should prefer the
diagnostic form.
