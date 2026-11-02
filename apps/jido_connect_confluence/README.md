# Jido Connect Confluence

`jido_connect_confluence` is the reviewed Confluence Cloud provider package for
`jido_connect`. It uses the official Confluence Cloud REST API v2 directly.

## Actions

| Action ID | Effect | Description |
|---|---|---|
| `confluence.space.get` | read | Get one visible space by key |
| `confluence.page.list` | read | List pages in one resolved space |
| `confluence.page.get` | read | Get bounded readable text and the web URL of one page |
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

## Page reads

`confluence.page.get` reads one page with its ADF body and returns `kind`,
`account`, `id`, `title`, `revision_id`, `version`, `space_id`, `url`, `text`,
`character_count` and `truncated`.

### Source URL

`url` is the page's address in the Confluence web UI: the validated tenant
endpoint, such as `https://example.atlassian.net/wiki`, joined with the page's
`_links.webui`. It comes from the page response itself, without a list
request. The read fails with the normalized invalid-response error when
`webui` is missing, absolute, protocol-relative or longer than 4,096
characters, or carries a query or fragment. It fails the same way when
`_links.base` names a root other than the tenant endpoint. The URL is never
built from `_links.base`.

### Text

Page text comes from the shared ADF projection,
`Jido.Connect.Atlassian.ADF.project/2`. Paragraphs, headings and code blocks
end a line, and a hard break starts a new one. List items start with `- ` or
their number, and nested lists are indented. Text loses its formatting.
Linked text is followed by its target in parentheses, for links of any
scheme, so pages with `http:` or `mailto:` links read where the former strict
rendering failed. Mentions, emoji and status lozenges render their display
text, inline cards their URL and a rule `---`.

The supported nodes are `paragraph`, `heading`, `codeBlock`, `text`,
`hardBreak`, `rule`, `bulletList`, `orderedList`, `listItem`, `taskList`,
`taskItem`, `decisionList`, `decisionItem`, `blockquote`, `panel`, `expand`,
`nestedExpand`, `layoutSection`, `layoutColumn`, `table`, `tableRow`,
`tableHeader`, `tableCell`, `mention`, `emoji`, `status` and `inlineCard`. The
supported text marks are `link` and the formatting marks `strong`, `em`,
`code`, `strike`, `underline`, `subsup`, `textColor` and `backgroundColor`.

### Unsupported content

Other node and mark types are unsupported, for example `mediaSingle`,
`media`, `caption`, `extension`, `bodiedExtension`, `inlineExtension`, `date`,
`placeholder`, `blockCard`, `embedCard` and the `annotation` mark of inline
comments. So are a mention or emoji without display text, an inline card
without URL and a link without target. The optional input `on_unsupported`
chooses the outcome:

- `"fail"`, the default, fails the read with the error that page reads
  returned before this input existed: a `Jido.Connect.Error.ProviderError`
  with reason `:invalid_response`. Its `details.adf_reason` is
  `:unsupported_adf_content`, which tells the caller that `"degrade"` would
  read the page.
- `"degrade"` returns the supported text and adds `unsupported_nodes`, which
  lists each skipped node or mark type once, in document order. The list is
  empty for a page without unsupported content.

Without `"degrade"` the output has no `unsupported_nodes`. Any other value
fails validation before a request is sent.

A skipped node is skipped with everything inside it, and only its own type is
listed. Degraded text therefore lacks the body of a macro with content
(`bodiedExtension`, such as an excerpt or page properties macro) and the
caption of an image. On the rich test page the excerpt text is missing, and
`bodiedExtension` appears in `unsupported_nodes`. An unsupported text mark,
such as `annotation`, is skipped while its text stays.

Malformed ADF and documents beyond the projection's nesting depth (default
64) or node count (default 50,000) fail the read in both modes with the
invalid-response error. Its `details.adf_reason` is `:invalid_adf`,
`:adf_depth_limit_exceeded` or `:adf_node_limit_exceeded`. The
`jido_connect_atlassian` README describes how to change these limits.

`details.field` is `"body"` whenever `adf_reason` is present. Other invalid
page responses, such as a body value that is not a JSON object or an unusable
`_links` entry, carry no `adf_reason`. Error details never name node types or
carry page text.

### Truncation

`max_characters` defaults to 20,000 and accepts at most 100,000. It counts
Unicode characters (grapheme clusters) of the projected text, list markers and
link targets included, so a multi-byte character is never cut.
`character_count` is the length of the whole text, and `truncated` tells
whether `text` was shortened.

### Denied pages

Confluence answers 404 for a page the user may not read, as for a missing
page. The read returns the normalized provider error with status 404 and no
page content.

## Page safety

List limits are 1 through 250, with a default of 25.

Create and update accept at most 100,000 Markdown characters. The converter
emits a fixed ADF v1 subset for paragraphs, headings, lists, block quotes,
fenced code, hard line breaks, horizontal rules, and HTTPS links.

ADF conversion lives in the shared `jido_connect_atlassian` package.
`Jido.Connect.Confluence.ADF` delegates `to_text/1` to its strict rendering and
`from_markdown/1` to its Markdown conversion with the limit above. Page reads
use the projection described under Page reads, not `to_text/1`.

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
