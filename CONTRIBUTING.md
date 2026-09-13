# Contributing

`jido_connect` is an umbrella of Jido connector packages. Keep changes scoped to
the package that owns the behavior, and keep provider business logic out of
generated Jido modules.

## Local Checks

Run the umbrella quality gate before opening a PR:

```sh
mix quality
```

The current gate runs formatting, warnings-as-errors compilation, and package
coverage. The release workflow is intentionally not defined yet.

For the demo harness:

```sh
cd dev/demo
mix format --check-formatted
mix compile --warnings-as-errors
mix test
```

## Package Boundaries

- `apps/jido_connect` owns DSL contracts, runtime authorization, generated Jido
  adapter behavior, error taxonomy, telemetry, and shared helper APIs.
- Provider packages own DSL declarations, auth helpers, provider clients,
  handlers, webhooks, scope resolvers, and provider-specific tests.
- `dev/demo` is a local host harness. Do not move demo persistence or UI
  contracts into published packages.

## Error And Observability Rules

- Return `Jido.Connect.Error` structs from package boundaries.
- Serialize public failures through `Jido.Connect.Error.to_map/1`.
- Emit telemetry through `Jido.Connect.Telemetry`.
- Sanitize logs, telemetry, and public payloads with `Jido.Connect.Sanitizer`.
- Never put raw credentials in plugin config, agent context, telemetry metadata,
  or public error details.

## Git Hygiene

Use conventional commit prefixes where practical, such as `feat:`, `fix:`,
`docs:`, `refactor:`, `test:`, and `chore:`.

Do not commit generated `cover/`, `doc/`, `_build/`, `deps/`, `.env`, or
`.secrets/` output.

## Compatibility Branches

Read [Branch support](docs/branch_support.md) before starting work. Target
`release/2.0` for v2 fixes and `release/3.0` for v3 work. Test each backport on
its own branch. Do not merge the v3 branch into the v2 branch.
