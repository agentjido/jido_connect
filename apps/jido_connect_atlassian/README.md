# Jido Connect Atlassian

`jido_connect_atlassian` holds Atlassian Document Format (ADF) support that
the `jido_connect_jira` and `jido_connect_confluence` packages share.

It is a library, not a product connector. It declares no provider, actions or
triggers, and it makes no HTTP requests.

## Installation

```elixir
def deps do
  [
    {:jido_connect_atlassian, "~> 0.8"}
  ]
end
```

Most host applications depend on `jido_connect_jira` or
`jido_connect_confluence` instead, which pull this package in.

## ADF projection

`Jido.Connect.Atlassian.ADF.project/2` renders an ADF v1 document as plain
text and returns `{:ok, %{text: text, unsupported_nodes: types}}`.

```elixir
{:ok, %{text: text, unsupported_nodes: skipped}} =
  Jido.Connect.Atlassian.ADF.project(document, on_unsupported: :degrade)
```

- Paragraphs, headings, list items and hard breaks end lines, in document
  order. Nested lists are indented; ordered lists keep their numbers.
- Linked text keeps its target, as `text (https://...)`. Mentions keep their
  display text.
- `on_unsupported: :fail`, the default, returns a
  `Jido.Connect.Error.ValidationError` with reason `:unsupported_adf_content`
  for any node or text mark outside the supported subset, such as
  `mediaSingle`, `extension` or `annotation`.
- `on_unsupported: :degrade` skips such content and lists each skipped type
  once, in document order, in `unsupported_nodes`. Content inside a skipped
  node is skipped with it and not listed: the body of a macro with content
  (`bodiedExtension`, such as an excerpt or page properties macro) and the
  caption of an image inside `mediaSingle` are missing from the text.
- Malformed documents (`:invalid_adf`) and documents beyond the nesting depth
  (default 64) or node count (default 50,000) fail in both modes. Change the
  limits per call with `:max_depth` and `:max_nodes`, or for all callers:

```elixir
config :jido_connect_atlassian, Jido.Connect.Atlassian.ADF,
  max_depth: 32,
  max_nodes: 20_000
```

The Jira package uses `:degrade` for issue descriptions, comment bodies and
webhook comment bodies. The module documentation of
`Jido.Connect.Atlassian.ADF` describes the rendering, the error reasons and
the limits in full.

## Strict ADF to text

`Jido.Connect.Atlassian.ADF.to_text/1` is the strict rendering. The
Confluence package reads pages with it: `confluence.page.get` renders page ADF
through `Jido.Connect.Confluence.ADF`, which delegates to `to_text/1`
unchanged, and does not use `project/2`. `to_text/1` fails the whole document
with `:error` on any node or text mark outside its supported subset and on
links that are not HTTPS.

## Markdown to ADF

`Jido.Connect.Atlassian.ADF.from_markdown/2` converts bounded Markdown into a
fixed ADF v1 subset for paragraphs, headings, lists, block quotes, fenced code,
hard line breaks, horizontal rules and HTTPS links. Option `:max_length` bounds
the input; the default is 100,000 characters.

## Quality checks

Run from this package directory:

```sh
mix quality
```
