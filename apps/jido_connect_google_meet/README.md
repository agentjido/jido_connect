# Jido Connect Google Meet

Google Meet provider package for Jido Connect.

This package depends on `jido_connect_google` for shared Google OAuth,
transport, scope, and account behavior. It keeps Meet-specific DSL, handlers,
schemas, normalized structs, and tests package-local as those surfaces are
added.

## Status

This scaffold declares the provider package, user OAuth profile, Meet scope
resolver, generated Jido plugin shell, and normalized Zoi-backed structs.
Recording/transcript, trigger, and catalog-pack work is intentionally split into
later Beadwork tasks.

## Normalized Structs

- `Jido.Connect.Google.Meet.Space`
- `Jido.Connect.Google.Meet.ConferenceRecord`
- `Jido.Connect.Google.Meet.Participant`
- `Jido.Connect.Google.Meet.Recording`
- `Jido.Connect.Google.Meet.Transcript`

## OAuth Scopes

The provider declares the shared Google identity scopes plus Meet product
scopes:

- `openid`
- `email`
- `profile`
- `https://www.googleapis.com/auth/meetings.space.readonly`
- `https://www.googleapis.com/auth/meetings.space.created`

## Tool Surface

- `google.meet.space.create`
- `google.meet.space.get`
- `google.meet.conference_record.list`
- `google.meet.conference_record.get`

No Meet triggers are exposed yet. The generated plugin and provider metadata
are present so later tasks can add action families without changing package
wiring.

## Tool Availability

Generated plugin availability is available from the scaffold and will report
one entry per generated action or trigger as those tools are added:

```elixir
Jido.Connect.Google.Meet.Plugin.tool_availability(%{connection: connection})
```
