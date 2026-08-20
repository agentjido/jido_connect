# Jido Connect Trello

`jido_connect_trello` is the reviewed Trello provider package for
`jido_connect`. It uses the official hosted Trello MCP endpoint at
`https://mcp.trello.com/v1`.

## Actions

The package supplies exactly 23 typed actions:

- `trello.board.get`
- `trello.list.list`, `trello.list.get`, `trello.list.create`,
  `trello.list.update`, `trello.list.move`, and `trello.list.archive`
- `trello.label.list`
- `trello.card.list`, `trello.card.get`, `trello.card.search`,
  `trello.card.create`, `trello.card.update`, `trello.card.move`,
  `trello.card.complete`, `trello.card.archive`, `trello.card.label.attach`,
  and `trello.card.label.detach`
- `trello.checklist.list`, `trello.checklist.create`,
  `trello.checklist.update`, `trello.checklist.item.create`, and
  `trello.checklist.item.update`

Each action has a fixed remote tool and a fixed remote action. Caller input
cannot select an MCP endpoint, connector, or tool. The package does not expose
generic MCP discovery or call actions.

## Installation

```elixir
def deps do
  [
    {:jido_connect_trello, "~> 0.8"}
  ]
end
```

## Authentication and board binding

Use the `:oauth_user` credential profile. The MCP runtime keeps the OAuth
credential in its lease. Public action input and provider errors do not contain
the credential.

`Jido.Connect.Trello.OAuth` supplies a host callback boundary. It discovers the
authorization server from the fixed MCP resource, uses PKCE, and supports a
configured client or dynamic client registration. The host must keep returned
OAuth state and `secret_data` encrypted and single-use. It stores
`mcp_endpoint`, `refresh_token`, and `oauth_client` as encrypted credential
fields. Only `mcp_endpoint` can enter a runtime lease.

Each connection must contain this board identity in lease metadata:

- `board_name`
- `board_url`
- `board_ari`
- `board_object_id`
- `board_short_id`
- `workspace_object_id`

The provider checks all fields. The URL must be an HTTPS Trello board URL. The
ARI, object ID, short ID, and workspace ID must agree with the selected board.
The provider injects this identity into remote calls. Caller input cannot
replace it.

## Safety

Read actions do not need confirmation. Write actions require AI confirmation.
Archive actions are destructive and always require confirmation. Each write has
a safe preview.

The provider validates its local copy of every remote tool schema before a
call. The MCP runtime also keeps its endpoint generation, credential version,
connection revision, schema fingerprint, and final pre-send fences. It does not
automatically retry a write after the write can have been sent.

Remote results must use a documented structured-content result or one JSON text
envelope. The provider rejects malformed success results and schema drift.

## Catalog packs

- `:trello_reader` contains the eight read actions.
- `:trello_editor` contains read and non-destructive write actions.
- `:trello_destructive` contains only list archive and card archive.

## Quality checks

Run from this package directory:

```sh
mix quality
```
