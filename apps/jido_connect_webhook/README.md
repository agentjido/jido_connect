# Jido Connect Webhook

Generic inbound webhook provider package for Jido Connect.

This package provides a provider-agnostic webhook integration for Jido Connect,
supporting HMAC-SHA256 signature verification, replay protection, and normalized
delivery metadata for any inbound webhook source.

## Status

This is a **scaffold**. Verification primitives, trigger fragments, catalog packs,
and host documentation will be added in subsequent waves.

## Auth Profiles

The provider supports one authentication profile:

- **Signing secret** (`:signing_secret`): A shared secret used to compute
  HMAC-SHA256 signatures over the raw request body. Stored in the host
  credential lease and never exposed in telemetry or public payloads.

## Verification Profile

`Jido.Connect.InboundWebhook.VerificationProfile` normalizes webhook
verification parameters so generic primitives can adapt to different
providers:

| Field | Default | Description |
|---|---|---|
| `signature_header` | `"x-signature"` | HTTP header carrying the HMAC signature |
| `timestamp_header` | `nil` | HTTP header carrying the request timestamp |
| `digest_prefix` | `""` | Prefix prepended to the hex digest (e.g. `"sha256="`) |
| `timestamp_tolerance_seconds` | `nil` | Max clock skew in seconds (`nil` to skip) |

## Modules

| Module | Purpose |
|---|---|
| `Jido.Connect.InboundWebhook` | Spark DSL integration (provider module) |
| `Jido.Connect.InboundWebhook.Verification` | HMAC-SHA256 verification primitives |
| `Jido.Connect.InboundWebhook.VerificationProfile` | Verification configuration struct |

## Security

- Signing secrets are never stored in the provider module.
- Secrets are received from the host credential lease at verification time.
- All signature comparisons use constant-time comparison to prevent timing attacks.
- Replay protection is available via delivery-id deduplication.

## Live-Test Guidance

The offline test suite exercises provider metadata, auth profiles, and
verification primitives through injected values and does **not** call live
webhook endpoints.

### Running Tests

Run focused quality checks from the package root:

```sh
cd apps/jido_connect_webhook
mix quality
```

Or from the umbrella root:

```sh
mix test apps/jido_connect_webhook/test --no-deps-check
```

## Package Quality Gates

The webhook package enforces these quality gates:

- **Formatting**: `mix format --check-formatted` must pass.
- **Compilation**: `mix compile --warnings-as-errors` must pass.
- **Test coverage**: `mix test --cover` must meet the 80% threshold configured
  in `mix.exs`.
- **Quality alias**: `mix quality` runs all three gates in sequence.
