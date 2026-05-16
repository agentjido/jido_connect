defmodule Jido.Connect.InboundWebhook do
  @moduledoc """
  Generic inbound webhook integration authored with the `Jido.Connect` Spark DSL.

  This provider enables hosts to accept inbound webhook deliveries from
  any source that signs payloads with HMAC-SHA256. It provides:

  - Shared verification primitives (HMAC-SHA256 signature validation)
  - Replay protection via delivery-id deduplication
  - Normalized delivery metadata via `Jido.Connect.WebhookDelivery`
  - Auth and verification profile structs for host configuration

  ## Auth Profiles

  The provider supports a single authentication profile:

  - **Signing secret** (`:signing_secret`): A shared secret used to compute
    HMAC-SHA256 signatures over the raw request body. Hosts store the secret
    in the credential lease and never expose it in telemetry or public payloads.

  ## Capabilities

  - **HMAC verification** (`:hmac_verification`): Verify inbound webhook
    signatures using configurable header names and digest prefixes.
  """

  use Jido.Connect,
    fragments: [
      Jido.Connect.InboundWebhook.Triggers.InboundDelivery
    ]

  integration do
    id(:webhook)
    name("Webhook")

    description(
      "Generic inbound webhook verification, replay protection, and normalized delivery metadata."
    )

    category(:tool_bridge)
    docs([])
  end

  catalog do
    package(:jido_connect_webhook)
    status(:available)
    tags([:webhook, :verification, :infrastructure])

    capability :hmac_verification do
      kind(:webhook)
      feature(:hmac_webhook_verification)
      label("HMAC webhook verification")

      description(
        "Verify inbound webhook signatures using HMAC-SHA256 with configurable headers and digest prefixes."
      )
    end

    capability :inbound_delivery do
      kind(:webhook)
      feature(:webhook_inbound_delivery)
      label("Inbound webhook delivery")

      description(
        "Receive normalized inbound webhook deliveries with header, body, and query metadata, plus replay deduplication."
      )
    end
  end

  auth do
    api_key :signing_secret do
      default?(true)
      owner(:tenant)
      subject(:webhook)
      label("Webhook signing secret")
      setup :api_key_shared_secret
      credential_fields([:signing_secret])
      lease_fields([:signing_secret])

      scopes([])
      default_scopes([])
    end
  end

  defdelegate catalog_packs, to: Jido.Connect.InboundWebhook.CatalogPacks, as: :all
  defdelegate verifier_pack, to: Jido.Connect.InboundWebhook.CatalogPacks, as: :verifier
  defdelegate receiver_pack, to: Jido.Connect.InboundWebhook.CatalogPacks, as: :receiver

  policies do
    policy :webhook_access do
      label("Webhook access")
      description("Host verifies the actor may receive webhook deliveries for this connection.")
      subject({:connection, :owner})
      owner({:connection, :owner})
      decision(:allow_operation)
    end
  end
end
