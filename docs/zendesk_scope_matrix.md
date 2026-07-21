# Zendesk Scope Matrix

The Zendesk connector treats OAuth scope coverage as action and trigger metadata,
resolved at runtime by `Jido.Connect.Zendesk.ScopeResolver`.

## Scope Resolution

Every action and trigger declares:

- Static `scopes` metadata in its DSL `access` block — the least-privilege
  scope advertised through the action catalog.
- A provider-local `scope_resolver` for runtime scope satisfaction checks.
- Auth profile coverage — every scope must be listed in the provider's
  `default_scopes` or `optional_scopes`.

## Scope Inventory

| Scope | Auth Profile | Default | Description |
|---|---|:---:|---|
| `read` | API token, OAuth2 | ✓ | Read tickets, users, organizations |
| `write` | API token, OAuth2 | ✗ | Create and update resources |
| `tickets:read` | API token, OAuth2 | ✓ | Read ticket data |
| `tickets:write` | API token, OAuth2 | ✗ | Create and update tickets |
| `users:read` | API token, OAuth2 | ✓ | Read user information |

## Action → Scope Mapping

| Action ID | Effect | Required Scopes |
|---|---|---|
| `zendesk.ticket.list` | read | `read`, `tickets:read` |
| `zendesk.ticket.search` | read | `read`, `tickets:read` |
| `zendesk.ticket.get` | read | `read`, `tickets:read` |
| `zendesk.ticket.create` | write | `write`, `tickets:write` |
| `zendesk.ticket.update` | write | `write`, `tickets:write` |
| `zendesk.ticket.comment.list` | read | `read`, `tickets:read` |
| `zendesk.ticket.comment.add` | write | `write`, `tickets:write` |
| `zendesk.user.list` | read | `read`, `users:read` |
| `zendesk.organization.list` | read | `read` |

## Trigger → Scope Mapping

| Trigger ID | Required Scopes |
|---|---|
| `zendesk.ticket.changed` | `read`, `tickets:read` |
| `zendesk.ticket.comment.changed` | `read`, `tickets:read` |

Triggers receive webhook deliveries and do not call Zendesk APIs directly,
but scope coverage is declared to ensure the host connection has at least
read access to the relevant resource type.

## Least-Privilege Guidance

- **Read-only surfaces** (dashboards, monitoring): use the `:api_token` profile
  with default scopes (`read`, `tickets:read`, `users:read`) and the
  `:zendesk_reader` catalog pack.

- **Agent assist** (AI-assisted replies): use the `:oauth2` profile with
  optional write scopes (`write`, `tickets:write`) and the `:zendesk_editor`
  catalog pack. Request explicit confirmation for write actions.

- **Webhook-only**: triggers subscribe independently of actions. A connection
  with only `read` and `tickets:read` scopes can receive and verify webhooks
  but cannot perform mutations.
