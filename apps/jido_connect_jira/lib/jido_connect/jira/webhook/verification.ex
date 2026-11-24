defmodule Jido.Connect.Jira.Webhook.Verification do
  @moduledoc """
  Signature verification for Jira Cloud administrator webhooks.

  A webhook registered with a secret, on the Jira webhooks page or through
  `/rest/webhooks/1.0/webhook`, signs every delivery with an
  `X-Hub-Signature: sha256=<hex>` header: the lowercase hex HMAC-SHA256 of
  the raw request body under that secret. Verify the exact bytes received,
  before any JSON decoding.

  Deliveries of webhooks that Connect or OAuth 2.0 apps register follow a
  separate contract and are not verified here.
  """

  alias Jido.Connect.{Data, Error, WebhookDelivery}
  alias Jido.Connect.Jira.Webhook
  alias Jido.Connect.Webhook, as: CoreWebhook

  @doc """
  Reads the signature, the delivery identifier and the flow from the headers.

  Jira sends a distinct numeric `X-Atlassian-Webhook-Identifier` with every
  delivery; the event name is only in the body.
  """
  @spec parse_headers(map()) :: %{
          delivery_id: String.t() | nil,
          flow: String.t() | nil,
          signature: String.t() | nil
        }
  def parse_headers(headers) when is_map(headers) do
    %{
      delivery_id: CoreWebhook.header(headers, "x-atlassian-webhook-identifier"),
      flow: CoreWebhook.header(headers, "x-atlassian-webhook-flow"),
      signature: CoreWebhook.header(headers, "x-hub-signature")
    }
  end

  @doc """
  Verifies an `X-Hub-Signature` value against the raw body and the webhook
  secret.

  Returns `:ok`, or `{:error, %Jido.Connect.Error.AuthError{}}` with reason
  `:missing_secret`, `:missing_signature` or `:invalid_signature`. A body or
  signature that is not a string, such as a header passed as a list, counts
  as invalid.
  """
  @spec verify_signature(term(), term(), String.t() | nil) ::
          :ok | {:error, Error.AuthError.t()}
  def verify_signature(body, signature, secret)
      when is_binary(body) and (is_binary(signature) or is_nil(signature)) and
             (is_binary(secret) or is_nil(secret)) do
    CoreWebhook.verify_hmac_sha256(body, signature, secret,
      prefix: "sha256=",
      missing_secret_message: "Jira webhook secret is required",
      missing_signature_message: "Jira webhook signature is required",
      invalid_signature_message: "Jira webhook signature is invalid",
      invalid_signature_reason: :invalid_signature
    )
  end

  def verify_signature(_body, _signature, _secret),
    do: {:error, Error.auth("Jira webhook signature is invalid", reason: :invalid_signature)}

  @doc """
  Verifies a delivery and returns it as a `Jido.Connect.WebhookDelivery`.

  The signature is checked over the raw `body` before it is decoded. The
  delivery carries the identifier header as `delivery_id`, `webhookEvent` as
  `event`, and the signal of `Jido.Connect.Jira.Webhook.normalize_event/1`
  when the event is one the triggers normalize. Option `:seen_delivery_ids`
  marks a repeated identifier as a duplicate.
  """
  @spec verify_delivery(binary(), map(), String.t() | nil, keyword()) ::
          {:ok, WebhookDelivery.t()} | {:error, Error.AuthError.t() | Error.ProviderError.t()}
  def verify_delivery(body, headers, secret, opts \\ []) do
    parsed = parse_headers(headers)

    with :ok <- verify_signature(body, parsed.signature, secret),
         {:ok, payload} <- decode_body(body),
         {:ok, delivery} <-
           WebhookDelivery.verified(:jira, %{
             delivery_id: parsed.delivery_id,
             event: Data.get(payload, "webhookEvent"),
             headers: headers,
             payload: payload,
             duplicate?:
               CoreWebhook.duplicate?(
                 parsed.delivery_id,
                 Keyword.get(opts, :seen_delivery_ids, [])
               ),
             metadata: %{signature: parsed.signature, flow: parsed.flow}
           }) do
      {:ok, put_normalized_signal(delivery)}
    end
  end

  defp put_normalized_signal(%WebhookDelivery{payload: payload} = delivery) do
    case Webhook.normalize_event(payload) do
      {:ok, signal} -> WebhookDelivery.put_signal(delivery, signal)
      {:error, _reason} -> delivery
    end
  end

  defp decode_body(body) do
    case CoreWebhook.decode_json(body,
           provider: :jira,
           message: "Jira webhook payload is invalid JSON"
         ) do
      {:ok, %{} = payload} ->
        {:ok, payload}

      {:ok, _payload} ->
        {:error,
         Error.provider("Jira webhook payload must be a JSON object",
           provider: :jira,
           reason: :invalid_payload
         )}

      error ->
        error
    end
  end
end
