# Jido Connect Bitbucket

`jido_connect_bitbucket` is the Bitbucket Cloud provider package for
`jido_connect`.

The package has one reviewed read action:

| Action ID | Effect | Description |
|---|---|---|
| `bitbucket.pull_request.list` | read | List pull requests for one repository |

It does not include write actions, generic HTTP actions, or MCP actions.

## Installation

```elixir
def deps do
  [
    {:jido_connect_bitbucket, "~> 0.8"}
  ]
end
```

## Authentication

Use an Atlassian account email and API token. The client sends them with HTTP
Basic authentication. Credential values stay in the credential lease and are
not included in normalized action output or provider errors.

The connection can set `metadata.api_endpoint` to an alternate HTTPS endpoint.
If it does not set this field, the package uses the official Bitbucket Cloud
REST v2 endpoint:

```text
https://api.bitbucket.org/2.0
```

The connection subject ID is the non-secret `account` value in action output.

## Action contract

`bitbucket.pull_request.list` accepts:

- `workspace` and `repository`: URL-safe slugs with letters, numbers, `.`, `_`,
  and `-`
- `state`: `open`, `merged`, `declined`, or `superseded`; default `open`
- `limit`: 1 through 50; default 20
- `page`: 1 through 10,000; default 1

The client calls:

```text
GET /repositories/{workspace}/{repository}/pullrequests
```

It sends the uppercase state plus `pagelen` and `page` query parameters. The
normalized result uses snake-case keys and `kind: "pull_requests"`.

## Catalog pack

The `:bitbucket_reader` pack includes only
`bitbucket.pull_request.list`.

## Quality checks

Run these checks from this package directory:

```sh
mix quality
```
