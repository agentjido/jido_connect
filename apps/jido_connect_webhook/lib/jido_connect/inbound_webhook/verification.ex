defmodule Jido.Connect.InboundWebhook.Verification do
  @moduledoc """
  Pure helpers for generic HMAC-SHA256 webhook verification.

  This module provides provider-agnostic verification primitives that
  work with any inbound webhook that signs payloads with HMAC-SHA256.
  Provider-specific connectors (GitHub, Slack, etc.) delegate to
  `Jido.Connect.Webhook` (the shared core) and may also use these
  helpers directly.

  The signing secret is **never** stored or exposed by this module.
  It is received from the host credential lease at verification time.

  ## Verification Profile

  See `Jido.Connect.InboundWebhook.VerificationProfile` for configuration
  of signature header names, digest prefixes, and timestamp tolerance.
  """

  alias Jido.Connect.{Error, WebhookDelivery}
  alias Jido.Connect.Webhook, as: CoreWebhook
  alias Jido.Connect.InboundWebhook.VerificationProfile

  @doc """
  Parses verification-relevant headers from a request header map.

  Uses the `VerificationProfile` to locate the signature and optional
  timestamp headers by name.
  """
  @spec parse_headers(map(), VerificationProfile.t()) :: %{
          signature: String.t() | nil,
          timestamp: String.t() | nil
        }
  def parse_headers(headers, %VerificationProfile{} = profile) when is_map(headers) do
    %{
      signature: CoreWebhook.header(headers, profile.signature_header),
      timestamp:
        if(profile.timestamp_header,
          do: CoreWebhook.header(headers, profile.timestamp_header),
          else: nil
        )
    }
  end

  @doc """
  Verifies the HMAC-SHA256 signature of a raw webhook body.

  Uses the `VerificationProfile` to determine the digest prefix and
  delegates to `Jido.Connect.Webhook.verify_hmac_sha256/4`.
  """
  @spec verify_signature(String.t(), String.t() | nil, String.t() | nil, VerificationProfile.t()) ::
          :ok | {:error, Error.AuthError.t()}
  def verify_signature(body, signature, secret, %VerificationProfile{} = profile) do
    CoreWebhook.verify_hmac_sha256(body, signature, secret,
      prefix: profile.digest_prefix,
      missing_secret_message: "Webhook signing secret is required",
      missing_secret_reason: :missing_signing_secret,
      missing_signature_message: "Webhook signature is required",
      missing_signature_reason: :missing_signature,
      invalid_signature_message: "Webhook signature is invalid",
      invalid_signature_reason: :invalid_signature
    )
  end

  @doc """
  Verifies a complete webhook request: signature + optional timestamp freshness.

  Returns `{:ok, payload}` with the decoded JSON payload on success.
  """
  @spec verify_request(String.t(), map(), String.t() | nil, VerificationProfile.t(), keyword()) ::
          {:ok, map()} | {:error, Error.error()}
  def verify_request(body, headers, secret, %VerificationProfile{} = profile, opts \\ []) do
    parsed = parse_headers(headers, profile)

    with :ok <- verify_signature(body, parsed.signature, secret, profile),
         :ok <- maybe_verify_timestamp(parsed.timestamp, profile, opts),
         {:ok, payload} <- decode_body(body) do
      {:ok, payload}
    end
  end

  @doc """
  Verifies and returns a full `WebhookDelivery` struct.

  This is the highest-level verification entry point. It verifies the
  signature, decodes the body, and wraps the result in a
  `Jido.Connect.WebhookDelivery` with normalized metadata.
  """
  @spec verify_delivery(String.t(), map(), String.t() | nil, VerificationProfile.t(), keyword()) ::
          {:ok, WebhookDelivery.t()} | {:error, Error.error()}
  def verify_delivery(body, headers, secret, %VerificationProfile{} = profile, opts \\ []) do
    parsed = parse_headers(headers, profile)
    delivery_id = Keyword.get(opts, :delivery_id)
    seen_delivery_ids = Keyword.get(opts, :seen_delivery_ids, [])

    with :ok <- verify_signature(body, parsed.signature, secret, profile),
         :ok <- maybe_verify_timestamp(parsed.timestamp, profile, opts),
         {:ok, payload} <- decode_body(body),
         {:ok, delivery} <-
           WebhookDelivery.verified(:webhook, %{
             delivery_id: delivery_id,
             event: Keyword.get(opts, :event),
             headers: headers,
             payload: payload,
             source: Keyword.get(opts, :source),
             duplicate?: CoreWebhook.duplicate?(delivery_id, seen_delivery_ids),
             metadata: %{
               signature: parsed.signature,
               timestamp: parsed.timestamp,
               profile: %{
                 signature_header: profile.signature_header,
                 timestamp_header: profile.timestamp_header,
                 digest_prefix: profile.digest_prefix
               }
             }
           }) do
      {:ok, delivery}
    end
  end

  @doc """
  Checks whether a delivery ID has been seen before (replay protection).
  """
  @spec duplicate?(String.t() | nil, [String.t()]) :: boolean()
  def duplicate?(delivery_id, seen_delivery_ids) do
    CoreWebhook.duplicate?(delivery_id, seen_delivery_ids)
  end

  defp maybe_verify_timestamp(nil, %VerificationProfile{timestamp_header: nil}, _opts),
    do: :ok

  defp maybe_verify_timestamp(nil, %VerificationProfile{}, _opts),
    do: :ok

  defp maybe_verify_timestamp(timestamp, %VerificationProfile{} = profile, opts) do
    tolerance = profile.timestamp_tolerance_seconds

    if is_nil(tolerance) do
      :ok
    else
      now = Keyword.get(opts, :now, System.system_time(:second))

      case Integer.parse(timestamp) do
        {ts, _} when is_integer(ts) ->
          if abs(now - ts) <= tolerance do
            :ok
          else
            {:error,
             Error.auth("Webhook timestamp is stale",
               reason: :stale_timestamp
             )}
          end

        :error ->
          {:error,
           Error.auth("Webhook timestamp is invalid",
             reason: :invalid_timestamp
           )}
      end
    end
  end

  defp decode_body(body) do
    CoreWebhook.decode_json(body,
      provider: :webhook,
      message: "Webhook payload is invalid JSON"
    )
  end
end
