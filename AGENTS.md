# Agent Guidance

This repository contains the `jido_connect` umbrella and a local Phoenix demo
host.

## Work Management

This project tracks durable work with `bw` (Beadwork). Always run this before
starting work:

```sh
bw prime
```

Use Beadwork issues for roadmap, multi-step, or branch/PR work so plans,
progress, and decisions survive context compaction.

## Working Rules

- Prefer the existing Spark DSL and Zoi struct patterns.
- Keep provider DSL fragments, client API areas, webhook handlers, and tests in
  small capability-oriented groups. Avoid catch-all modules such as `Client.Rest`
  or single files that mix unrelated action, trigger, or event families.
- Keep generated Jido modules thin. They should carry metadata and delegate to
  `Jido.Connect` runtimes.
- Keep provider API logic in provider clients and handlers.
- Keep host-owned persistence, credential storage, and audit storage out of core
  package contracts.
- Use `Jido.Connect.Error` for normalized errors.
- Use `Jido.Connect.Sanitizer` before emitting telemetry or public payloads.
- Do not log or expose raw access tokens, refresh tokens, private keys, client
  secrets, signing secrets, or credential lease fields.

## Verification

From the umbrella root:

```sh
mix quality
```

From the demo app:

```sh
cd dev/demo
mix format --check-formatted
mix compile --warnings-as-errors
mix test
```

Release and Hex publishing automation are intentionally out of scope for now.

## Compatibility Lines

- Read `docs/branch_support.md` before dependency or API changes.
- `release/2.0` keeps Jido and Action v2.
- `release/3.0` follows Jido and Action v3. Prerelease Hex packages are allowed.
- The v3 line is for maintainer development. Do not add cross-major shims.
- Keep exact source references only where a required package is not on Hex.
- Update the dependency record and run the quality checks after each upstream update.
- Branch numbers identify compatibility lines, not published Connect versions.
