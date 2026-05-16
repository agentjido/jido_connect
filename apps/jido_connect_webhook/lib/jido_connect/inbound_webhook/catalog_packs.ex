defmodule Jido.Connect.InboundWebhook.CatalogPacks do
  @moduledoc """
  Curated catalog packs for generic inbound webhook capabilities.

  Packs are storage-free catalog filters that hosts pass to the catalog
  boundary to scope tool discovery and invocation.

  The webhook provider is trigger-only (no action tools). Triggers are
  subscribed to independently and are not listed in packs by default.
  Instead, packs scope the **capabilities** the host wishes to advertise:

  | Pack | Capabilities | Risk |
  |------|-------------|------|
  | `:webhook_verifier` | `hmac_verification` | read |
  | `:webhook_receiver` | `hmac_verification` + `inbound_delivery` | read |

  Hosts that want to receive and normalize inbound deliveries should use
  `:webhook_receiver`. Hosts that only need signature-check primitives
  (e.g. a custom pipeline) may use `:webhook_verifier`.
  """

  alias Jido.Connect.Catalog.Pack

  # Sentinel that will not match any catalog tool. Used by the verifier
  # pack to activate allow-list filtering while blocking all real tools.
  @verification_only ["webhook.capability.hmac_verification"]

  @inbound_delivery_trigger "webhook.inbound.delivery"

  @doc "Returns all built-in webhook catalog packs."
  def all, do: [verifier(), receiver()]

  @doc """
  Verification-only pack.

  Exposes the `hmac_verification` capability. The inbound delivery
  trigger is **not** included — hosts subscribe to triggers
  independently.
  """
  def verifier do
    Pack.new!(%{
      id: :webhook_verifier,
      label: "Webhook verifier",
      description:
        "HMAC-SHA256 signature verification primitives without inbound delivery trigger subscription.",
      filters: %{provider: :webhook},
      allowed_tools: @verification_only,
      metadata: %{
        package: :jido_connect_webhook,
        risk: :read,
        capabilities: [:hmac_verification]
      }
    })
  end

  @doc """
  Full receiver pack.

  Exposes both `hmac_verification` and `inbound_delivery` capabilities
  and allows the `webhook.inbound.delivery` trigger tool through the
  catalog boundary.
  """
  def receiver do
    Pack.new!(%{
      id: :webhook_receiver,
      label: "Webhook receiver",
      description:
        "Full inbound webhook receiver with HMAC verification, replay deduplication, and normalized delivery trigger.",
      filters: %{provider: :webhook},
      allowed_tools: [@inbound_delivery_trigger],
      metadata: %{
        package: :jido_connect_webhook,
        risk: :read,
        capabilities: [:hmac_verification, :inbound_delivery]
      }
    })
  end
end
