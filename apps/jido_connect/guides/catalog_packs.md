# Catalog Packs

Each Connect provider with executable Actions exposes a standard
`Jido.Connect.<Provider>.CatalogPacks` module.

```elixir
Jido.Connect.GitHub.catalog_packs()
Jido.Connect.Google.Drive.catalog_packs()
Jido.Connect.Slack.catalog_packs()
```

`CatalogPacks.all/0` returns a non-empty list of
`Jido.Connect.Catalog.Pack` values. Pack IDs are stable. Each pack selects at
least one generated Action.

## Pack Boundaries

Catalog packs contain Actions only. They do not contain triggers or provider
capabilities.

- Subscribe to triggers through the provider trigger API or a provider
  `TriggerPacks` module.
- Read provider capabilities from the integration catalog metadata or a
  provider capability module.
- Do not project a trigger or capability as a model tool.

Each Action pack has one standard risk label in `pack.metadata.risk`:

- `:read` or `:metadata`
- `:write`
- `:privileged`
- `:destructive`
- `:mixed`

Hosts should select the smallest pack that satisfies one Agent role.

## Jido AI Tool Sources

Read and metadata packs can become dynamic Jido AI tools:

```elixir
{:ok, source} =
  Jido.Connect.AI.CatalogToolSource.new(
    Jido.Connect.GitHub,
    Jido.Connect.GitHub.CatalogPacks.issues_read()
  )
```

Pass the source and current Connect runtime state from the trusted execution
host. Request data cannot add a source.

```elixir
context = %{
  jido_ai_tool_sources: [source],
  integration_context: connect_context,
  credential_lease: credential_lease
}

MyApp.GitHubAgent.cmd(agent, request, context: context)
```

The source configuration contains pack data, tool schemas, and reviewed
fingerprints. It does not contain credentials.

The Action context must contain:

- `:integration_context` with the tenant, actor, and connection.
- `:credential_lease` with current provider credentials.
- Any provider runtime dependency required by the connector. For example, a
  GitHub lease can contain `github_client: Jido.Connect.GitHub.Client`.

## Mutation Authorization

`CatalogToolSource.new/2` rejects packs that contain write, privileged,
destructive, or mixed Actions. It returns
`:catalog_mutation_tool_not_enabled`.

Do not bypass this error. Mutation tools need this host-owned flow:

1. The model proposes an Action call.
2. Jido AI records and reviews the proposed call.
3. The host calls `Jido.Connect.prepare/4`.
4. The host obtains authorization evidence.
5. The host calls `Jido.Connect.commit/4` with an authorization validator.
6. The result returns to the Agent thread.

Direct mutation invocation is not the production AI path.

## Catalog-Wide Gate

`Jido.Connect.CatalogPacksUmbrellaTest` checks every registered provider with
Actions. It verifies the standard module, pack IDs, risk labels, Action-only
selection, read-pack loading, and mutation-pack rejection.
