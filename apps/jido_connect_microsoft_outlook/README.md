# jido_connect_microsoft_outlook

Microsoft Outlook Mail connector package for Jido Connect.

Builds on the shared `jido_connect_microsoft` foundation package for OAuth
profiles, Graph transport, pagination, scopes, and error normalization. This
package owns the Outlook Mail integration DSL, action catalog, scope resolver,
and catalog packs.

## Installation

This package is part of the `jido_connect` umbrella and depends on
`jido_connect` and `jido_connect_microsoft`.

```elixir
def deps do
  [
    {:jido_connect_microsoft_outlook, in_umbrella: true}
  ]
end
```

## Usage

```elixir
# Get the integration spec
spec = Jido.Connect.MicrosoftOutlook.integration()

# List declared actions
spec.actions

# List catalog packs
Jido.Connect.MicrosoftOutlook.catalog_packs()
```

## Architecture

- **Integration DSL** – Declares the `microsoft_outlook` provider with mail
  actions, auth profiles reused from the Microsoft foundation, and catalog
  metadata.
- **Scope Resolver** – Maps action ids to required Microsoft Graph mail scopes.
- **Catalog Packs** – Curated tool surfaces (metadata, triage, send,
  destructive) for host policy enforcement.
- **Action Handlers** – Shell handlers that return `{:error, :not_implemented}`
  until full message actions are implemented in a follow-up task.

## License

MIT
