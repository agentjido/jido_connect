# Release Checklist

Use this checklist before a release candidate. Hex publishing automation is not
part of this repository.

## Baseline Guard

1. Confirm that the branch has only intentional release changes:

   ```sh
   git status --short --branch
   ```

2. Confirm that the release pull request has no whitespace errors and contains
   the intended change set:

   ```sh
   git diff --check
   git diff --stat origin/main...
   ```

3. Confirm that the existing `v0.8.0` safeguard tag is present. Do not create a
   `v0.9.0` tag until the user approves the release.

## Package Verification

Run the root quality gate from the umbrella root:

```sh
mix quality
```

The quality gate runs these commands:

```sh
mix format --check-formatted
mix compile --warnings-as-errors
mix test
```

Run the documentation and dependency checks separately:

```sh
MIX_ENV=docs mix docs
mix hex.outdated
mix hex.audit
```

Verify the core MCP replacement and its security regression tests:

```sh
mix test \
  apps/jido_connect/test/jido_connect/catalog_test.exs \
  apps/jido_connect/test/jido_connect/mcp_test.exs \
  apps/jido_connect/test/jido_connect/mcp

cd apps/jido_connect
mix quality
MIX_ENV=docs mix docs
mix hex.build
```

Verify that the two MCP-backed connectors use the core bridge:

```sh
mix test apps/jido_connect_x/test apps/jido_connect_trello/test
rg 'jido_connect_mcp|Jido\.MCP' apps/*/mix.exs apps/*/lib dev/demo/lib
```

The final command must return no results.

Each package exposes a local quality alias when you must isolate one app. For
example:

```sh
cd apps/jido_connect
mix quality
```

Check the connector factory separately:

```sh
cd pi-connector-factory
bun install --frozen-lockfile
bun outdated
bun run check
```

## Demo Host Verification

The Phoenix demo is not part of the packages. It is the reference host for
OAuth, app installation callbacks, tunnel URLs, webhooks, action execution, and
poll sensors.

```sh
cd dev/demo
mix format --check-formatted
mix compile --warnings-as-errors
mix test
```

## Package Inventory

The umbrella contains 40 package projects:

- Core: `jido_connect`
- Shared services: `jido_connect_google`, `jido_connect_microsoft`, and
  `jido_connect_webhook`
- Google services: Analytics, Calendar, Contacts, Docs, Drive, Forms, Gmail,
  Meet, Search Console, Sheets, Slides, and Tasks
- Microsoft services: Calendar, OneDrive, and Outlook
- Other providers: Airtable, Asana, Bitbucket, Cal.com, Calendly, Confluence,
  GitHub, GitLab, HubSpot, Intercom, Jira, Linear, Nextcloud, Notion, PostHog,
  Salesforce, Slack, Things, Trello, X, and Zendesk

Confirm that core `jido_connect` is `0.9.0`. Connector packages remain at
`0.8.0` until their separate releases:

```sh
rg 'version: "' apps/*/mix.exs
```

`dev/demo`, `.env`, `.secrets`, `_build`, `deps`, and generated docs are not
included in Hex packages.

## Publishing Notes

Hex publishing is deferred. Do not publish a package or create the `v0.9.0`
tag without explicit user approval. When publishing starts, publish
`jido_connect` first. Then publish the shared service packages and provider
packages that use it. Create the release tag only from the verified commit on
`main`.

The Action v3 beta branch temporarily uses an overridden Jido Action Git
dependency and an exact Jido Git commit. Skip the Hex package and publish steps
until upstream releases replace both pins.

Dependabot must remain enabled for vulnerability alerts, security updates, and
the update groups in `.github/dependabot.yml`.
