# GitHub Demo

The demo supports manual tokens, OAuth Apps, GitHub Apps, issue actions, issue
polling, and signed webhooks.

## Start the Demo

From the repository root, copy `.env.example` to `.env` and set the required
GitHub values. Then start the host:

```sh
cd dev/demo
mix deps.get
mix phx.server
```

Open `http://localhost:4000/integrations/github`.

For public callbacks, start ngrok from the repository root:

```sh
mix jido.connect.ngrok --port 4000
```

Set `JIDO_CONNECT_PUBLIC_BASE_URL` to the public URL.

## Manual Token

Set `GITHUB_TOKEN`, or enter a token on the GitHub integration page. Use
`GITHUB_TEST_REPO` as the default `owner/repository` value.

## OAuth App

Set:

- `GITHUB_CLIENT_ID`
- `GITHUB_CLIENT_SECRET`

Use this callback URL:

```text
<public-base-url>/integrations/github/oauth/callback
```

## GitHub App

Set:

- `GITHUB_APP_ID`
- `GITHUB_APP_SLUG`
- `GITHUB_CLIENT_ID`
- `GITHUB_CLIENT_SECRET`
- `GITHUB_PRIVATE_KEY_PATH`
- `GITHUB_WEBHOOK_SECRET`

Configure these URLs:

```text
Setup:          <public-base-url>/integrations/github/setup
Setup complete: <public-base-url>/integrations/github/setup/complete
OAuth callback: <public-base-url>/integrations/github/oauth/callback
Webhook:        <public-base-url>/integrations/github/webhook
```

Grant Issues read/write permission and Metadata read permission. Subscribe to
issue events. Keep the private key and all tokens outside source control.

## Test the Flow

The GitHub integration page can:

- list issues
- create an issue
- poll for new issues
- show connection and credential state

The webhook endpoint verifies `X-Hub-Signature-256`, uses
`X-GitHub-Delivery` for duplicate detection, and normalizes supported GitHub
events.
