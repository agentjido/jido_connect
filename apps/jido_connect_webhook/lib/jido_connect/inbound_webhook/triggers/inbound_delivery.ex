defmodule Jido.Connect.InboundWebhook.Triggers.InboundDelivery do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  triggers do
    webhook :inbound_delivery do
      id("webhook.inbound.delivery")
      resource(:delivery)
      verb(:watch)
      data_classification(:workspace_metadata)
      label("Inbound webhook delivery")

      description(
        "Receive normalized inbound webhook deliveries with header, body, and query metadata, plus replay deduplication."
      )

      verification(%{
        kind: :generic_webhook,
        signature: :hmac_sha256,
        header: "x-signature"
      })

      dedupe(%{key: [:delivery_id]})
      handler(Jido.Connect.InboundWebhook.Handlers.Triggers.InboundDeliveryWebhook)

      access do
        auth(:signing_secret)
        policies([:webhook_access])
      end

      config do
        field(:mode, :string,
          default: "hmac",
          description: "Verification mode: hmac, bearer, or unsigned."
        )

        field(:signature_header, :string,
          default: "x-signature",
          description: "HTTP header carrying the HMAC signature or bearer token."
        )

        field(:timestamp_header, :string,
          description: "HTTP header carrying the request timestamp (optional)."
        )

        field(:digest_prefix, :string,
          default: "",
          description: "Prefix prepended to the hex digest (e.g. \"sha256=\", \"v0=\")."
        )

        field(:timestamp_tolerance_seconds, :integer,
          description: "Clock-skew tolerance in seconds (nil to skip)."
        )

        field(:replay_id_header, :string,
          description: "Header carrying the unique delivery/event ID for replay protection."
        )
      end

      signal do
        field(:delivery_id, :string)
        field(:event, :string)
        field(:source, :string)
        field(:duplicate?, :boolean)
        field(:headers, :map)
        field(:payload, :map)
        field(:query, :map)
        field(:metadata, :map)
        field(:delivery, :map)
      end
    end
  end
end
