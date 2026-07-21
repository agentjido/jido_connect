# ADR: Service Account and Domain-Wide Delegation Boundaries

## Status

Accepted

## Context

Google service accounts and Workspace domain-wide delegation introduce a second
and third authentication mode beyond the user OAuth profile already in
production. Service accounts allow a host application to call Google APIs using
a server-owned identity. Domain-wide delegation extends service accounts so the
host can impersonate any Workspace user within a domain after a Google Workspace
administrator authorizes the delegation.

Both modes require sensitive credential material: a service-account JSON key
containing a private key, and optionally a delegated subject email. The existing
codebase already models auth profiles (`:service_account`,
`:domain_delegated_service_account`), connection helpers
(`Connections.service_account_connection/2`,
`Connections.domain_delegated_service_account_connection/2`), and a
`ServiceAccount` runtime that builds JWT assertions, mints access tokens, and
produces `CredentialLease` structs.

The question this ADR answers is: which parts of service-account and domain-
delegation support belong in published package contracts, and which parts must
remain host-owned configuration, storage, and operational responsibility?

## Decision

### Package contracts

The following belong in `jido_connect`, `jido_connect_google`, and product
connector packages. They are published APIs that hosts and product packages rely
on.

1. **Auth profile metadata.** `AuthProfile` structs for `:service_account` and
   `:domain_delegated_service_account` declare profile kind, owner, subject
   type, setup method, credential fields, lease fields, and scope metadata.
   Product packages reference these profiles in DSL declarations to declare
   which profiles an action or trigger supports.

2. **Connection shaping helpers.** `Connections.service_account_connection/2`
   and `Connections.domain_delegated_service_account_connection/2` produce
   `Connection` structs with the correct provider, profile, tenant, owner,
   subject, scope, and metadata fields. These helpers do not store anything.
   They return structs that the host persists.

3. **Credential lease minting.** `ServiceAccount.credential_lease/3` accepts a
   host-owned connection and a host-provided credential payload, mints a
   Google access token through the JWT bearer grant, and returns a
   `CredentialLease` bound to the connection. The lease carries only
   short-lived runtime material (`access_token`, `expires_at`, scopes) and
   never stores the private key.

4. **JWT assertion building.** `ServiceAccount.assertion/2` constructs and
   signs a JWT from host-provided credentials and scopes. This is a pure
   function with no side effects beyond RSA signing. Product packages and
   tests may call it directly for scope or claim verification.

5. **DSL auth profile declarations.** The Spark DSL entities
   `service_account/1` and `domain_delegated_service_account/1` allow product
   integrations to declare service-account and domain-delegation support in
   their `auth` sections. Product actions and triggers list supported profiles
   via `@auth_profiles`, and the catalog and generated modules expose these
   to hosts.

6. **Profile validation.** `ServiceAccount.credential_lease/3` validates that
   the connection profile is `:service_account` or
   `:domain_delegated_service_account` before attempting token minting. Core
   authorization checks validate that the lease profile matches the connection
   profile, that the lease has not expired, and that effective scopes satisfy
   the operation requirements.

7. **Scope catalogs and resolvers.** Product packages declare static and
   dynamic scopes for each action and trigger. Service-account scopes are
   resolved the same way as user OAuth scopes: through product scope resolvers
   and the shared `Jido.Connect.Google.Scopes` helpers.

8. **Error mapping.** Service-account token errors (invalid private key,
   missing scopes, expired tokens, Google API errors) are mapped to sanitized
   `Jido.Connect.Error` values with no raw credential leakage.

### Host-owned configuration and storage

The following are the host application's responsibility. Packages must not
store, persist, or require access to these.

1. **Service-account JSON key storage.** The private key, client email, and
   private key ID are host-owned secrets. The package never stores them. The
   host passes them as a map argument to `ServiceAccount.credential_lease/3`
   at runtime, typically loaded from a secrets manager or encrypted store.

2. **Durable connection records.** `Connection` structs produced by the
   package helpers are metadata. The host persists them in its own database or
   store. The package does not ship Ecto schemas, migrations, or storage
   behaviours.

3. **Delegated subject configuration.** For domain-wide delegation, the host
   decides which Workspace user to impersonate. The delegated subject email is
   passed as the `:subject` option when building the connection or minting the
   lease. The package does not maintain a subject directory or manage
   delegation grants.

4. **Google Admin Console configuration.** Enabling domain-wide delegation,
   authorizing API scopes for the service account, and managing Workspace
   domain settings are administrative operations performed in the Google Admin
   Console. The package does not automate or persist Admin Console
   configuration.

5. **Credential rotation and lifecycle.** Rotating service-account keys,
   updating private keys in secrets storage, and managing key expiration are
   host operational responsibilities. When the host rotates a key, it updates
   the credential payload in its secrets store; the next lease minting picks
   up the new key automatically.

6. **Scope authorization policy.** Deciding whether an actor may use a
   service-account connection or impersonate a particular Workspace user is a
   host policy decision. Hosts pass a `policy` callback to control which
   actors can use which connections. The package provides the policy hook but
   does not implement host authorization logic.

7. **OAuth state and callback persistence.** User OAuth callback state and
   session management remain host-owned. Service accounts bypass OAuth
   entirely (using JWT bearer grants), so this concern applies only to the
   user profile, but the boundary is the same: packages do not persist session
   state.

8. **Watch channel and checkpoint persistence.** Poll checkpoints, push
   notification channels, and Workspace Events subscriptions are host-owned
   durable state. Packages accept checkpoint or channel state as arguments and
   return updated values, following the same pattern established in the
   watch/checkpoint persistence design.

## Rationale

### Why the package owns lease minting but not key storage

`CredentialLease` is the established portable credential handoff between host
storage and package runtimes. The user OAuth profile already uses this pattern:
the host stores a refresh token, the package accepts it, mints an access token,
and returns a lease. Service accounts follow the identical shape: the host
stores the JSON key, the package accepts it, mints an access token, and returns
a lease. Keeping lease minting in the package means product handlers remain
profile-agnostic—they consume `lease.fields.access_token` regardless of whether
the lease came from user OAuth, a service account, or domain delegation.

### Why connection shaping is a helper, not storage

`Connection` is a durable grant metadata struct. It is validated and bound to
leases at runtime, but it is not a persistence contract. Making the helpers
return structs instead of persisting them means the host can store connections
in any backend (Ecto, in-memory, Redis, etc.) without the package dictating
storage technology.

### Why delegated subjects are host-owned

The choice of which Workspace user to impersonate is an authorization decision.
Different hosts will have different rules: some will allow any actor to
impersonate any user in the domain, while others will restrict impersonation to
a specific admin or service mailbox. Encoding this in the package would either
be too restrictive or too permissive. Passing the subject as an option lets each
host implement its own delegation policy.

### Why Admin Console setup is host-owned

Google Workspace domain-wide delegation requires a Workspace administrator to
authorize the service account for specific OAuth scopes. This is an
administrative, one-time configuration step that happens outside the application.
Automating it would require Admin SDK API calls with their own credential
management, adding significant complexity for a step that happens rarely and
often requires human approval. The package should document the setup steps but
not attempt to automate them.

## Consequences

- Product handlers remain profile-agnostic. A Sheets read handler receives a
  `CredentialLease` and does not need to know whether the underlying access
  token came from user OAuth, a service account, or domain delegation.
- Host applications must provide secure storage for service-account private
  keys and manage key rotation independently.
- The `ServiceAccount` runtime will never log or expose private keys, client
  secrets, or raw assertion payloads. Error messages are sanitized through
  `Jido.Connect.Error`.
- Adding a new auth profile (for example, Workload Identity Federation) follows
  the same pattern: the package adds profile metadata, a connection helper,
  and a lease minting function; the host adds storage and configuration.
- The boundary is consistent with the existing user OAuth profile, the
  `host_owned_storage.md` principle, and the watch/checkpoint persistence
  design.

## References

- `docs/host_owned_storage.md` — host-owned storage principle.
- `docs/architecture.md` — package layers and core contracts.
- `docs/google_connector_conventions.md` — product package conventions.
- `docs/google_extension_patterns.md` — action and trigger extension guide.
- `docs/google_watch_checkpoint_persistence.md` — watch/checkpoint design.
- `apps/jido_connect_google/lib/jido_connect/google/service_account.ex` —
  service-account JWT bearer runtime.
- `apps/jido_connect_google/lib/jido_connect/google/connections.ex` —
  connection shaping helpers.
- `apps/jido_connect_google/lib/jido_connect/google/auth_profiles.ex` —
  auth profile metadata.
- `apps/jido_connect/lib/jido_connect/contracts/credential_lease.ex` —
  credential lease contract.
- `apps/jido_connect/lib/jido_connect/contracts/connection.ex` —
  connection contract.
