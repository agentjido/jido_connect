# Authoring A Jido Connect Provider

Provider packages should stay thin. The core `jido_connect` package owns the
runtime contracts, generated Jido adapter behavior, auth/credential boundaries,
scope checks, availability checks, and common provider helper APIs.

## Shape

A provider package should follow this layout:

- `lib/jido_connect/<provider>/integration.ex`
- `lib/jido_connect/<provider>/oauth.ex`
- `lib/jido_connect/<provider>/client.ex`
- `lib/jido_connect/<provider>/webhook.ex`
- `lib/jido_connect/<provider>/scope_resolver.ex` when scopes depend on input
- `lib/jido_connect/<provider>/handlers/actions/*`
- `lib/jido_connect/<provider>/handlers/triggers/*`
- `test/jido_connect/<provider>/*_test.exs`

Start a scaffold with:

```sh
mix jido.connect.gen.provider google_sheets
```

The generated package depends on `{:jido_connect, "~> 3.0"}` from Hex. For
local work in the Jido Connect source umbrella, use
`mix jido.connect.gen.provider google_sheets --local-path ../jido_connect`.
The path is relative to the generated provider package, not the shell's
current directory. Replace the path dependency with the Hex dependency before
publishing a provider package.

## Rules

- Generated Jido modules must stay thin adapters.
- Provider handlers read credentials only from `CredentialLease.fields`.
- Raw credentials never go through plugin config or agent context.
- Actions and triggers declare all supported auth profiles in the DSL.
- Use a scope resolver when required scopes depend on action params.
- Normalize provider API failures into `Jido.Connect.Error.ProviderError`.
- Verify webhooks with pure functions and return normalized signal payloads.
- Keep durable connection storage and credential storage in the host app.

## Core Helpers

- `Jido.Connect.OAuth` builds common OAuth URLs and Req defaults.
- `Jido.Connect.Http` builds common bearer requests and provider errors.
- `Jido.Connect.Webhook` verifies HMAC signatures and decodes JSON payloads.
- `Jido.Connect.Polling` handles checkpoint params and latest checkpoints.
- `Jido.Connect.Catalog` derives host-facing catalog metadata from integration
  specs and generated projections.
