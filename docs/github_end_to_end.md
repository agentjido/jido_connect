# GitHub End-To-End Demo Plan

This package should keep generated Jido modules thin. The local demo host owns
OAuth, connection storage, webhook HTTP endpoints, and credential leasing. The
integration package owns DSL metadata, generated Jido adapters, runtime
delegation, provider action handlers, and GitHub API calls.

## Current Runnable Path

The primary end-to-end path today is the GitHub App flow:

1. Create a local GitHub App from the generated manifest.
2. Install it on a writable test repository.
3. Store durable connection metadata in the host.
4. Mint a short-lived installation-token `CredentialLease`.
5. Invoke the generated list and create issue actions.
6. Initialize and tick the generated new issues poll sensor.
7. Verify issue webhooks through the local ngrok endpoint.

This proves the compile-time modules, Jido adapter contract, credential lease
boundary, GitHub HTTP client, action execution, poll execution, and Jido signal
emission without requiring a host web app.

## Local Host Harness

This umbrella currently contains only `jido_connect` and `jido_connect_github`.
For the first GitHub live loop, this repo includes a Phoenix demo host at
`dev/demo`. It is intentionally outside the package umbrella so the publishable
apps remain only `jido_connect` and provider packages.

Run it with:

```sh
set -a && source .env && set +a
cd dev/demo
mix deps.get
mix phx.server
```

The harness exposes GitHub routes:

- `GET /health`
- `GET /integrations/github/setup`
- `GET /integrations/github/setup/complete`
- `GET /integrations/github/oauth/callback`
- `GET /integrations/github/oauth/start`
- `POST /integrations/github/webhook`

The host should store connections in memory first. A connection record only
stores durable metadata and a credential reference. Raw tokens should stay in a
separate in-memory credential store and be surfaced to integration runtimes only
through `CredentialLease`.

## Ngrok Helper

Once the demo host is running locally, start a tunnel with:

```sh
mix jido.connect.ngrok --port 4000
```

The task stays attached until interrupted. It prints the public base URL. The
GitHub manifest task prints the callback, setup, and webhook URLs to paste into
the GitHub App settings.

If your local host requires a specific host header, pass:

```sh
mix jido.connect.ngrok --port 4000 --host-header localhost:4000
```

Local credential names are listed in `.env.example`. Copy that file to `.env`
for local use. The real env file is ignored by git.

If ngrok is installed but not authenticated, set `NGROK_AUTHTOKEN` locally or
pass it once:

```sh
set -a && source .env && set +a
mix jido.connect.ngrok --port 4000
```

or pass the token directly once:

```sh
mix jido.connect.ngrok --port 4000 --authtoken ...
```

The task runs `ngrok config add-authtoken` before opening the tunnel.

## GitHub App Manifest Helper

There is no single `gh app create` command. Use the GitHub App manifest flow
instead:

```sh
mix jido.connect.github.app.manifest --open
```

The task auto-detects a running ngrok HTTPS tunnel. You can also pass the URL:

```sh
mix jido.connect.github.app.manifest --url https://example.ngrok-free.app --open
```

For an organization-owned app:

```sh
mix jido.connect.github.app.manifest --owner my-org --open
```

Submit the generated form in the browser. GitHub redirects to the configured
setup complete URL with a temporary `code`. Copy that code and run:

```sh
mix jido.connect.github.app.convert CODE
```

The conversion task uses `gh api`, writes `.secrets/github-app.json`, writes the
private key to `.secrets/github-app.pem`, and upserts these `.env` keys:

- `GITHUB_APP_ID`
- `GITHUB_APP_SLUG`
- `GITHUB_CLIENT_ID`
- `GITHUB_CLIENT_SECRET`
- `GITHUB_WEBHOOK_SECRET`
- `GITHUB_PRIVATE_KEY_PATH`

After conversion, restart the demo with `.env` loaded and use the GitHub page's
install URL. GitHub App installation callbacks can return to
`/integrations/github/oauth/callback` with both `installation_id` and `code`;
the demo stores the installation connection from that callback.

## OAuth Flow

For a GitHub OAuth App:

1. Configure callback URL to the local tunnel URL:
   `/integrations/github/oauth/callback`.
2. `oauth/start` creates a CSRF state and redirects to GitHub.
3. `oauth/callback` exchanges `code` for an access token.
4. The host creates:
   - `Connection`
   - credential store entry
   - `CredentialLease` when running tools

For the first local spike, a manual token is acceptable. OAuth should be the
next step once the action and poll demo is green.

For a GitHub App demo, configure:

- Callback URL: `<public-base-url>/integrations/github/oauth/callback`
- Setup URL: `<public-base-url>/integrations/github/setup`
- Webhook URL: `<public-base-url>/integrations/github/webhook`
- Webhook secret: same value as `GITHUB_WEBHOOK_SECRET`
- Repository permissions:
  - Issues: read/write
  - Metadata: read
- Subscribe to:
  - Issues

Download the private key and store it outside source control. Put only its local
path in `GITHUB_PRIVATE_KEY_PATH`.

## Webhook Flow

Webhook support should be tested at the host boundary before adding webhook DSL:

1. GitHub sends `POST /integrations/github/webhook`.
2. The host verifies `X-Hub-Signature-256`.
3. The host maps `X-GitHub-Event` plus payload into a local event.
4. Once webhook DSL exists, the host will dispatch that event into the generated
   sensor/runtime path.

Until webhook DSL exists, local webhook testing should verify:

- signature validation
- event routing by GitHub event name and action
- `issues.opened` payload normalization into the same signal shape used by poll
  sensors
- duplicate delivery behavior using GitHub delivery id

## Local Webhook Simulation

Use one of these modes:

- `ngrok`, `cloudflared`, or GitHub's webhook redelivery UI against the local
  host endpoint for real GitHub events.
- `curl` fixtures with computed `X-Hub-Signature-256` for deterministic tests.
- A local fake GitHub server for contract tests against the REST client by
  setting `:jido_connect_github, :github_api_base_url`.

The fixture path should be preferred in CI. The tunnel path should be used for
manual demos.

## Acceptance Demo

The first complete demo should show:

1. Plugin availability starts as `:connection_required`.
2. After a connection and lease are present, availability is `:available`.
3. `ListIssues` calls GitHub and returns repository issues.
4. `CreateIssue` creates an issue in a disposable test repo.
5. `NewIssues` poll emits a `github.issue.new` Jido signal.
6. A webhook payload posted to the local host is verified and normalized into
   the same signal shape.

For write demos, create in a disposable or package test repository, verify the
new issue with a brief retry loop around generated `ListIssues`, then close the
created issue through `Jido.Connect.GitHub.Client.close_issue/3`. GitHub's issue
list endpoint can be briefly eventually consistent after create and close.

## Remaining Package Work

- Add a generic Phoenix demo host app once the umbrella has more providers.
- Add webhook DSL once the contract is clear.
- Add webhook generated sensor modules.
- Add local fake GitHub HTTP server tests for `Jido.Connect.GitHub.Client`.
- Add OAuth app flow tests around host-owned connection and credential lease
  creation.
