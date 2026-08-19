# Jido Connect X

`jido_connect_x` is the reviewed read-only X provider package for
`jido_connect`. It uses the official local XMCP streamable HTTP endpoint at
`http://127.0.0.1:8000/mcp`.

## Actions

The package supplies exactly three typed actions:

- `x.account.get` calls `get_users_me`.
- `x.bookmark.list` calls `get_users_me`, then `get_users_bookmarks`.
- `x.post.list` calls `get_users_me`, then `get_users_posts`.

The list actions put the verified account ID in the remote `id` field. Public
input cannot select the endpoint, remote tool, action, account ID, user ID, or
username. The package does not expose generic MCP discovery or call actions.

## Installation

```elixir
def deps do
  [
    {:jido_connect_x, "~> 0.8"}
  ]
end
```

## Local connection contract

Use the `:local_mcp` credential profile. The connection metadata must contain:

- `mcp_endpoint_id: "x"`
- `expected_username`: an X username without `@`, with 1 to 15 ASCII letters,
  digits, or underscores
- a non-negative `connection_revision` for the MCP endpoint lease fence

The credential lease must contain `mcp_endpoint` and a non-negative
`credential_version`. The endpoint must normalize to streamable HTTP with the
exact base URL `http://127.0.0.1:8000` and path `/mcp`. The provider rejects
`localhost`, other loopback forms, private network hosts, different ports,
HTTPS hosts, user information, query strings, fragments, and other paths.

Username verification first checks the strict X username syntax. It then
changes ASCII letters in the configured and authenticated usernames to
lowercase and compares the two normalized strings exactly. The result keeps
the username spelling returned by X.

## Inputs and results

`x.account.get` has no input. `x.bookmark.list` accepts `max_results` from 1 to
100 with a default of 20. `x.post.list` accepts `max_results` from 5 to 100 with
a default of 5. Both list actions accept an optional `pagination_token` with at
most 2,048 characters.

All public fields use snake case. Account results use `social_account`.
Bookmark and post results contain the verified account, item count, requested
limit, next cursor, and strict items with `id`, `text`, derived X URL,
`author_id`, and `created_at`.

## Safety

All actions are reads and need no confirmation. The package publishes only the
`:x_reader` catalog pack.

The provider verifies an expected schema hash before every remote call. It
accepts only a non-empty structured-content object or one JSON text block. It
rejects malformed success results, identity mismatch, and schema drift with
secret-safe `Jido.Connect.Error` values.

The shared MCP runtime owns endpoint generation, final dispatch fencing,
credential rotation, revocation, and endpoint cleanup. The package does not
copy this lease logic.

## Quality checks

Run from this package directory:

```sh
mix quality
```
