defmodule Jido.Connect.Slack.Webhook.Verification do
  @moduledoc false

  alias Jido.Connect.{Data, Error, WebhookDelivery}
  alias Jido.Connect.Slack.Webhook.Normalizer
  alias Jido.Connect.Webhook, as: CoreWebhook

  @max_skew_seconds 60 * 5

  def parse_headers(headers) when is_map(headers) do
    %{
      signature: header(headers, "x-slack-signature"),
      timestamp: header(headers, "x-slack-request-timestamp")
    }
  end

  def verify_signature(body, headers, signing_secret, opts \\ [])

  def verify_signature(_body, _headers, nil, _opts) do
    {:error, Error.auth("Slack signing secret is required", reason: :missing_signing_secret)}
  end

  def verify_signature(_body, _headers, "", _opts) do
    {:error, Error.auth("Slack signing secret is required", reason: :missing_signing_secret)}
  end

  def verify_signature(body, headers, signing_secret, opts)
      when is_binary(body) and is_map(headers) and is_binary(signing_secret) do
    parsed = parse_headers(headers)
    now = Keyword.get(opts, :now, System.system_time(:second))

    with {:ok, timestamp} <- parse_timestamp(parsed.timestamp),
         :ok <- reject_replay(timestamp, now),
         {:ok, base} <- signature_base(body, timestamp) do
      CoreWebhook.verify_hmac_sha256(base, parsed.signature, signing_secret,
        prefix: "v0=",
        missing_signature_message: "Slack request signature is invalid",
        missing_signature_reason: :invalid_signature,
        invalid_signature_message: "Slack request signature is invalid",
        invalid_signature_reason: :invalid_signature
      )
    end
  end

  def verify_request(body, headers, signing_secret, opts \\ []) do
    with {:ok, delivery} <- verify_delivery(body, headers, signing_secret, opts) do
      {:ok, delivery.payload}
    end
  end

  def verify_delivery(body, headers, signing_secret, opts \\ []) do
    with :ok <- verify_signature(body, headers, signing_secret, opts),
         {:ok, payload} <- decode_body(body),
         {:ok, delivery} <-
           WebhookDelivery.verified(:slack, %{
             delivery_id: Data.get(payload, "event_id"),
             event: get_in(payload, ["event", "type"]) || Data.get(payload, "type"),
             headers: headers,
             payload: payload,
             duplicate?:
               CoreWebhook.duplicate?(
                 Data.get(payload, "event_id"),
                 Keyword.get(opts, :seen_delivery_ids, [])
               ),
             metadata: %{team_id: Data.get(payload, "team_id")}
           }) do
      {:ok, Normalizer.maybe_put_normalized_signal(delivery)}
    end
  end

  defp parse_timestamp(nil) do
    {:error, Error.auth("Slack request timestamp is required", reason: :missing_timestamp)}
  end

  defp parse_timestamp("") do
    {:error, Error.auth("Slack request timestamp is required", reason: :missing_timestamp)}
  end

  defp parse_timestamp(timestamp) when is_binary(timestamp) do
    case Integer.parse(timestamp) do
      {integer, ""} ->
        {:ok, integer}

      _other ->
        {:error, Error.auth("Slack request timestamp is invalid", reason: :invalid_timestamp)}
    end
  end

  defp reject_replay(timestamp, now) do
    if abs(now - timestamp) <= @max_skew_seconds,
      do: :ok,
      else: {:error, Error.auth("Slack request timestamp is stale", reason: :stale_timestamp)}
  end

  defp signature_base(body, timestamp), do: {:ok, "v0:#{timestamp}:#{body}"}

  defp decode_body(body) do
    case CoreWebhook.decode_json(body,
           provider: :slack,
           message: "Slack event payload is invalid JSON"
         ) do
      {:ok, %{} = payload} ->
        {:ok, payload}

      {:ok, _payload} ->
        {:error,
         Error.provider("Slack event payload must be a JSON object",
           provider: :slack,
           reason: :invalid_payload
         )}

      error ->
        error
    end
  end

  defp header(headers, key) do
    CoreWebhook.header(headers, key)
  end
end
