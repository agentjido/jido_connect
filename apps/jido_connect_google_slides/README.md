# Jido Connect Google Slides

Google Slides provider package for Jido Connect.

This package depends on `jido_connect_google` for shared Google OAuth,
transport, scope, and account behavior. It keeps Slides-specific DSL,
handlers, schemas, normalized structs, and tests package-local as those
surfaces are added.

## Actions

Actions will be added as the Slides surface is implemented.

## Auth Profiles

Slides declares a user OAuth profile:

- `:user` for app-user OAuth authorization-code grants.

Every Slides action will advertise this profile through the Jido Connect action
catalog.

## OAuth Scopes

The provider declares the shared Google identity scopes plus Slides product
scopes:

- `openid`
- `email`
- `profile`
- `https://www.googleapis.com/auth/presentations.readonly`
- `https://www.googleapis.com/auth/presentations`

Read-only operations should use `presentations.readonly` when possible.
Presentation creation and mutation should require `presentations`.

## Catalog Packs

- `:google_slides_readonly` includes presentation metadata and content reads only.
- `:google_slides_editor` adds presentation creation and updates. Includes all
  Slides tools.

Pack delegates are available directly from the provider module:

```elixir
alias Jido.Connect.Google.Slides

Slides.catalog_packs()    # [readonly_pack, editor_pack]
Slides.readonly_pack()    # :google_slides_readonly
Slides.editor_pack()      # :google_slides_editor
```
