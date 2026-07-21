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

3. Create and push an annotated safeguard tag before a large branch
   consolidation.

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

The umbrella contains 36 package projects:

- Core: `jido_connect`
- Shared services: `jido_connect_google`, `jido_connect_microsoft`,
  `jido_connect_mcp`, and `jido_connect_webhook`
- Google services: Analytics, Calendar, Contacts, Docs, Drive, Forms, Gmail,
  Meet, Search Console, Sheets, Slides, and Tasks
- Microsoft services: Calendar, OneDrive, and Outlook
- Other providers: Airtable, Asana, Cal.com, Calendly, GitHub, GitLab, HubSpot,
  Intercom, Jira, Linear, Nextcloud, Notion, PostHog, Salesforce, Slack, and
  Zendesk

Confirm that every package has the intended version before release:

```sh
rg 'version: "' apps/*/mix.exs
```

`dev/demo`, `.env`, `.secrets`, `_build`, `deps`, and generated docs are not
included in Hex packages.

## Publishing Notes

Hex publishing is deferred. When publishing starts, publish `jido_connect`
first. Then publish the shared service packages and provider packages that use
it. Create the release tag only from the verified commit on `main`.

Dependabot must remain enabled for vulnerability alerts, security updates, and
the update groups in `.github/dependabot.yml`.
