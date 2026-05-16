# Jido Connect Webhook

Generic inbound webhook provider package for Jido Connect.

This package provides a provider-agnostic webhook integration for Jido Connect,
supporting HMAC-SHA256 signature verification, replay protection, and normalized
delivery metadata for any inbound webhook source.

## Status

Available. Verification primitives, trigger fragments, catalog packs, and host
documentation are in place.

## Auth Profiles

The provider supports one authentication profile:

- **Signing secret** (`:signing_secret`): A shared secret used to compute
  HMAC-SHA256 signatures over the raw request body. Stored in the host
  credential lease and never exposed in telemetry or public payloads.

## Capabilities

| Capability | Kind | Description |
|---|---|---|
| `hmac_verification` | webhook | Verify inbound webhook signatures using HMAC-SHA256 with configurable headers and digest prefixes |
| `inbound_delivery` | webhook | Receive normalized inbound webhook deliveries with header, body, and query metadata, plus replay deduplication |

## Catalog Packs

Packs scope tool discovery at the catalog boundary. The webhook provider
offers two packs:

| Pack | Capabilities | Tools | Risk |
|---|---|---|---|
| `:webhook_verifier` | `hmac_verification` | none (triggers excluded) | read |
| `:webhook_receiver` | `hmac_verification`, `inbound_delivery` | `webhook.inbound.delivery` | read |

```elixir
# List available packs
packs = Jido.Connect.InboundWebhook.catalog_packs()

# Get a specific pack
verifier = Jido.Connect.InboundWebhook.verifier_pack()
receiver = Jido.Connect.InboundWebhook.receiver_pack()
```

Triggers are subscribed to independently. Use `:webhook_receiver` when you
want the catalog boundary to expose the `webhook.inbound.delivery` trigger tool.
Use `:webhook_verifier` when you only need verification primitives.

## Verification Profile

`Jido.Connect.InboundWebhook.VerificationProfile` normalizes webhook
verification parameters so generic primitives can adapt to different
providers:

| Field | Default | Description |
|---|---|---|
| `mode` | `:hmac` | Verification mode: `:hmac`, `:bearer`, or `:unsigned` |
| `signature_header` | `"x-signature"` | HTTP header carrying the HMAC signature or bearer token |
| `timestamp_header` | `nil` | HTTP header carrying the request timestamp |
| `digest_prefix` | `""` | Prefix prepended to the hex digest (e.g. `"sha256="`, `"v0="`) |
| `timestamp_tolerance_seconds` | `nil` | Max clock skew in seconds (`nil` to skip) |
| `replay_id_header` | `nil` | Header carrying the unique delivery/event ID for replay protection |

## Route Mounting

To receive inbound webhooks in a Phoenix host application, mount a route
through the API pipeline and read the raw body before verification.

### Step 1: Use a caching body reader

Add a module that caches the raw body so both signature verification and
JSON parsing see the same bytes:

```elixir
# lib/my_app_web/cache_body_reader.ex
defmodule MyAppWeb.CacheBodyReader do
  def read_body(conn, opts) do
    {:ok, body, conn} = Plug.Conn.read_body(conn, opts)
    {:ok, body, Plug.Conn.assign(conn, :raw_body, body)}
  end
end
```

Configure it in your endpoint:

```elixir
# lib/my_app_web/endpoint.ex
plug Plug.Parsers,
  parsers: [:urlencoded, :multipart, :json],
  pass: ["*/*"],
  json_decoder: Phoenix.json_library(),
  body_reader: {MyAppWeb.CacheBodyReader, :read_body, []}
```

### Step 2: Mount the webhook route

```elixir
# lib/my_app_web/router.ex
scope "/", MyAppWeb do
  pipe_through(:api)
  post "/webhooks/inbound", WebhookController, :inbound
end
```

### Step 3: Verify and normalize in the controller

```elixir
# lib/my_app_web/controllers/webhook_controller.ex
defmodule MyAppWeb.WebhookController do
  use MyAppWeb, :controller

  alias Jido.Connect.InboundWebhook.{Verification, VerificationProfile}

  def inbound(conn, _params) do
    body = conn.assigns[:raw_body] || ""
    headers = extract_headers(conn)
    secret = get_secret(conn)    # from your credential lease

    profile = VerificationProfile.new!(%{
      signature_header: "x-signature",
      replay_id_header: "x-delivery-id"
    })

    case Verification.verify_delivery(body, headers, secret, profile,
           seen_delivery_ids: known_delivery_ids()) do
      {:ok, delivery} ->
        # Delivery is verified. Normalize and dispatch as needed.
        {:ok, signal} = Jido.Connect.InboundWebhook.Normalizer.normalize_signal(delivery)
        # ... handle signal ...
        json(conn, %{ok: true, delivery_id: delivery.delivery_id})

      {:error, reason} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{ok: false, error: Verification.redacted_error(reason)})
    end
  end

  defp extract_headers(conn) do
    conn.req_headers
    |> Enum.into(%{}, fn {k, v} -> {k, v} end)
  end

  defp get_secret(_conn), do: System.get_env("WEBHOOK_SIGNING_SECRET")

  defp known_delivery_ids do
    # Replace with your persistence layer (e.g. ETS, Redis, database)
    []
  end
end
```

## Replay and Deduplication

The webhook provider includes built-in replay protection via delivery-ID
deduplication. The contract is:

1. **Replay ID header** — Configure `replay_id_header` on the
   `VerificationProfile` to specify which HTTP header carries the unique
   delivery/event ID (e.g. `"x-delivery-id"`).

2. **Seen IDs** — Pass a list of previously seen delivery IDs via the
   `:seen_delivery_ids` option to `verify_delivery/5`. The provider
   checks whether the incoming ID is already in that list and sets
   `duplicate?: true` on the `WebhookDelivery` struct when it is.

3. **Fallback key** — When no replay ID header is configured or the
   header is absent, `Normalizer.dedupe_key/1` falls back to a composite
   of the event type and source (`"#{event}:#{source}"`), or `nil` when
   neither is available.

4. **Host responsibility** — The provider does **not** persist seen IDs.
   Hosts are responsible for maintaining a deduplication store (e.g. an
   ETS table, Redis set, or database append log) sized to their replay
   window.

5. **Safety** — Duplicate deliveries are still verified and returned as
   `{:ok, delivery}` with `delivery.duplicate? == true`. Hosts decide
   whether to process, skip, or re-ack duplicate deliveries.

### Example: ETS-based dedup store

```elixir
defmodule MyAppWeb.DedupeStore do
  @table :webhook_seen_ids
  @ttl_seconds 3600

  def start_link(_opts), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)

  def seen_ids do
    try do
      :ets.match_object(@table, {:_, _})
      |> Enum.map(fn {id, _expires_at} -> id end)
    catch
      :error, :badarg -> []
    end
  end

  def mark_seen(id) do
    expires_at = System.system_time(:second) + @ttl_seconds
    :ets.insert(@table, {id, expires_at})
  end

  # Periodically prune expired entries in production
end
```

## Modules

| Module | Purpose |
|---|---|
| `Jido.Connect.InboundWebhook` | Spark DSL integration (provider module) |
| `Jido.Connect.InboundWebhook.CatalogPacks` | Curated catalog packs for webhook capabilities |
| `Jido.Connect.InboundWebhook.Verification` | HMAC-SHA256, bearer, and unsigned verification primitives |
| `Jido.Connect.InboundWebhook.VerificationProfile` | Verification configuration struct |
| `Jido.Connect.InboundWebhook.Normalizer` | Delivery normalization and header sanitization |

## Security

- Signing secrets are never stored in the provider module.
- Secrets are received from the host credential lease at verification time.
- All signature comparisons use constant-time comparison to prevent timing attacks.
- Replay protection is available via delivery-id deduplication.
- Sensitive headers (signature, authorization, cookie) are redacted in
  normalized signals and delivery summaries.

## Local Demo and Live-Test Guidance

The offline test suite exercises provider metadata, auth profiles,
verification primitives, and catalog packs through injected values and
does **not** call live webhook endpoints.

### Running Tests

Run focused quality checks from the package root:

```sh
cd apps/jido_connect_webhook
mix quality
```

Or from the umbrella root:

```sh
mix test apps/jido_connect_webhook/test --no-deps-check
```

### Testing Locally with cURL

Start your Phoenix server and send a test webhook:

```sh
# Compute HMAC signature
SECRET="my-test-secret"
BODY='{"event":"test","data":"hello"}'
SIG=$(echo -n "$BODY" | openssl dgst -sha256 -hmac "$SECRET" | awk '{print $NF}')

# Send the webhook
curl -X POST http://localhost:4000/webhooks/inbound \
  -H "Content-Type: application/json" \
  -H "x-signature: $SIG" \
  -H "x-delivery-id: test-$(date +%s)" \
  -d "$BODY"
```

### Testing with ngrok

To test with a real external provider, expose your local server:

```sh
ngrok http 4000
```

Configure the provider's webhook URL to the ngrok HTTPS forwarding URL,
then inspect deliveries in the ngrok dashboard or your server logs.

### Testing Unsigned Mode

For quick local iteration without signatures:

```elixir
profile = VerificationProfile.new!(%{mode: :unsigned})
```

**Never use unsigned mode in production.**

## Package Quality Gates

The webhook package enforces these quality gates:

- **Formatting**: `mix format --check-formatted` must pass.
- **Compilation**: `mix compile --warnings-as-errors` must pass.
- **Test coverage**: `mix test --cover` must meet the 80% threshold configured
  in `mix.exs`.
- **Quality alias**: `mix quality` runs all three gates in sequence.
