# Jido Connect Confluence

`jido_connect_confluence` is the reviewed Confluence Cloud provider package for
`jido_connect`. It uses the official Confluence Cloud REST API v2 directly.

## Actions

| Action ID | Effect | Description |
|---|---|---|
| `confluence.space.get` | read | Get one visible space by key |
| `confluence.page.list` | read | List pages in one resolved space |
| `confluence.page.get` | read | Get bounded readable text from page ADF |
| `confluence.page.create` | write | Create a page from bounded Markdown |
| `confluence.page.update` | write | Update a page after version and space checks |
| `confluence.page.delete` | destructive | Move a page to the trash |

The package does not expose generic HTTP or MCP call actions.

## Installation

```elixir
def deps do
  [
    {:jido_connect_confluence, "~> 0.8"}
  ]
end
```

## Authentication and tenant binding

Use an Atlassian account email and API token with HTTP Basic authentication.
Set the selected connection's `metadata.site_url` to its tenant site, for
example:

```text
https://example.atlassian.net/wiki
```

The client accepts only HTTPS tenant hosts directly under `atlassian.net`. It
rejects user information, query strings, fragments, non-default ports, and
unrecognized paths. It normalizes a valid root site URL to the `/wiki` API
root. Other metadata fields cannot select the credential target.

Credential fields stay in the credential lease. Request inspection, normalized
results, and provider errors do not include the email or API token.

## Page safety

List limits are 1 through 250, with a default of 25. Page reads return at most
100,000 characters and include `character_count` and `truncated` metadata.

Create and update accept at most 100,000 Markdown characters. The converter
emits a fixed ADF v1 subset for paragraphs, headings, lists, block quotes,
fenced code, hard line breaks, horizontal rules, and HTTPS links.

Update first gets the remote page. It checks the remote version and the resolved
space before it sends the next version. `force: true` bypasses only the version
equality check. It does not bypass the space check.

Mutation requests disable automatic Req retries. Errors record whether a
mutation could have been sent and keep raw provider bodies out of public error
details.

## Catalog packs

- `:confluence_reader` contains only the three read actions.
- `:confluence_editor` adds create and update. It does not include delete.
- `:confluence_destructive` contains only page delete.

Delete always requires confirmation and has a preview that contains only the
operation and selected page ID.

## Quality checks

Run from this package directory:

```sh
mix quality
```
