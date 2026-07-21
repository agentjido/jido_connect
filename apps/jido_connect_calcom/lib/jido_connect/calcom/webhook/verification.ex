defmodule Jido.Connect.Calcom.Webhook.Verification do
  @moduledoc false

  alias Jido.Connect.{Data, Error, WebhookDelivery}
  alias Jido.Connect.Calcom.Webhook.Normalizer
  alias Jido.Connect.Webhook, as: CoreWebhook

  @spec verify_signature(String.t(), map(), String.t()) ::
          :ok | {:error, Error.AuthError.t()}
  def verify_signature(body, headers, webhook_secret)

  def verify_signature(_body, _headers, nil) do
    {:error, Error.auth("Cal.com webhook secret is required", reason: :missing_webhook_secret)}
  end

  def verify_signature(_body, _headers, "") do
    {:error, Error.auth("Cal.com webhook secret is required", reason: :missing_webhook_secret)}
  end

  def verify_signature(body, headers, webhook_secret)
      when is_binary(body) and is_map(headers) and is_binary(webhook_secret) do
    signature = header(headers, "x-cal-signature-256")

    CoreWebhook.verify_hmac_sha256(body, signature, webhook_secret,
      missing_signature_message: "Cal.com webhook signature is missing",
      missing_signature_reason: :missing_signature,
      invalid_signature_message: "Cal.com webhook signature is invalid",
      invalid_signature_reason: :invalid_signature
    )
  end

  @spec verify_request(String.t(), map(), String.t()) ::
          {:ok, map()} | {:error, Error.AuthError.t() | Error.ProviderError.t()}
  def verify_request(body, headers, webhook_secret) do
    with {:ok, delivery} <- verify_delivery(body, headers, webhook_secret) do
      {:ok, delivery.payload}
    end
  end

  @spec verify_delivery(String.t(), map(), String.t(), keyword()) ::
          {:ok, WebhookDelivery.t()} | {:error, term()}
  def verify_delivery(body, headers, webhook_secret, opts \\ []) do
    with :ok <- verify_signature(body, headers, webhook_secret),
         {:ok, payload} <- decode_body(body),
         trigger_event <- Data.get(payload, "triggerEvent"),
         booking_uid <- booking_uid(payload),
         {:ok, delivery} <-
           WebhookDelivery.verified(:calcom, %{
             delivery_id: booking_uid,
             event: trigger_event,
             headers: headers,
             payload: payload,
             duplicate?:
               CoreWebhook.duplicate?(
                 booking_uid,
                 Keyword.get(opts, :seen_delivery_ids, [])
               ),
             metadata: %{trigger_event: trigger_event}
           }) do
      {:ok, Normalizer.maybe_put_normalized_signal(delivery)}
    end
  end

  defp decode_body(body) do
    CoreWebhook.decode_json(body,
      provider: :calcom,
      message: "Cal.com webhook payload is invalid JSON"
    )
  end

  defp header(headers, key), do: CoreWebhook.header(headers, key)

  defp booking_uid(%{"payload" => %{"uid" => uid}}) when is_binary(uid), do: uid
  defp booking_uid(%{"payload" => %{"id" => id}}) when is_integer(id), do: to_string(id)
  defp booking_uid(_payload), do: nil
end
