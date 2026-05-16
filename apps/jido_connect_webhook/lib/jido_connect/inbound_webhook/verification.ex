defmodule Jido.Connect.InboundWebhook.Verification do
  @moduledoc """
  Pure helpers for generic webhook verification.

  This module provides provider-agnostic verification primitives that
  support multiple authentication modes:

  - **HMAC-SHA256** (`:hmac`) — shared-secret signature verification
  - **Bearer/token** (`:bearer`) — static token comparison against a known value
  - **Unsigned** (`:unsigned`) — skips signature checks entirely (dev/test only)

  Additional capabilities:

  - **Timestamp tolerance** — rejects stale or replayed requests by comparing
    the request timestamp against the current clock
  - **Replay ID extraction** — extracts a delivery/event ID from a configurable
    header for deduplication
  - **Redacted error details** — returns safe error maps that strip secrets,
    tokens, and signatures

  The signing secret and bearer token are **never** stored or exposed by this
  module. They are received from the host credential lease at verification time.

  ## Verification Profile

  See `Jido.Connect.InboundWebhook.VerificationProfile` for configuration
  of mode, signature header names, digest prefixes, timestamp tolerance,
  and replay ID header.
  """

  alias Jido.Connect.{Error, Sanitizer, WebhookDelivery}
  alias Jido.Connect.Webhook, as: CoreWebhook
  alias Jido.Connect.InboundWebhook.VerificationProfile

  # ---------------------------------------------------------------------------
  # Header parsing
  # ---------------------------------------------------------------------------

  @doc """
  Parses verification-relevant headers from a request header map.

  Uses the `VerificationProfile` to locate the signature, optional
  timestamp, and optional replay ID headers by name.
  """
  @spec parse_headers(map(), VerificationProfile.t()) :: %{
          signature: String.t() | nil,
          timestamp: String.t() | nil,
          replay_id: String.t() | nil
        }
  def parse_headers(headers, %VerificationProfile{} = profile) when is_map(headers) do
    %{
      signature: CoreWebhook.header(headers, profile.signature_header),
      timestamp:
        if(profile.timestamp_header,
          do: CoreWebhook.header(headers, profile.timestamp_header),
          else: nil
        ),
      replay_id:
        if(profile.replay_id_header,
          do: CoreWebhook.header(headers, profile.replay_id_header),
          else: nil
        )
    }
  end

  # ---------------------------------------------------------------------------
  # HMAC-SHA256 verification
  # ---------------------------------------------------------------------------

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

  # ---------------------------------------------------------------------------
  # Bearer/token verification
  # ---------------------------------------------------------------------------

  @doc """
  Verifies a static bearer/token sent in the configured signature header.

  The caller passes the raw token value from the header (`header_token`) and
  the expected token from the credential lease (`expected_token`). The
  comparison is constant-time to prevent timing attacks.

  Returns `:ok` on match, or an `AuthError` when the token is missing or
  does not match.
  """
  @spec verify_bearer(String.t() | nil, String.t() | nil) ::
          :ok | {:error, Error.AuthError.t()}
  def verify_bearer(header_token, expected_token)

  def verify_bearer(_header_token, expected_token) when expected_token in [nil, ""] do
    {:error,
     Error.auth("Webhook bearer token is required",
       reason: :missing_bearer_token
     )}
  end

  def verify_bearer(header_token, _expected_token) when header_token in [nil, ""] do
    {:error,
     Error.auth("Webhook bearer token is missing from request",
       reason: :missing_bearer_token
     )}
  end

  def verify_bearer(header_token, expected_token)
      when is_binary(header_token) and is_binary(expected_token) do
    if Jido.Connect.Security.secure_compare?(header_token, expected_token) do
      :ok
    else
      {:error,
       Error.auth("Webhook bearer token does not match",
         reason: :invalid_bearer_token
       )}
    end
  end

  # ---------------------------------------------------------------------------
  # Mode-dispatched verification
  # ---------------------------------------------------------------------------

  @doc """
  Dispatches signature verification based on the profile mode.

  - `:hmac` — delegates to `verify_signature/4`
  - `:bearer` — delegates to `verify_bearer/2` using the parsed header token
  - `:unsigned` — always returns `:ok` (no verification)
  """
  @spec verify_by_mode(String.t(), String.t() | nil, String.t() | nil, VerificationProfile.t()) ::
          :ok | {:error, Error.AuthError.t()}
  def verify_by_mode(body, header_value, secret, %VerificationProfile{mode: :hmac} = profile) do
    verify_signature(body, header_value, secret, profile)
  end

  def verify_by_mode(_body, header_value, secret, %VerificationProfile{mode: :bearer}) do
    verify_bearer(header_value, secret)
  end

  def verify_by_mode(_body, _header_value, _secret, %VerificationProfile{mode: :unsigned}) do
    :ok
  end

  # ---------------------------------------------------------------------------
  # Full request verification
  # ---------------------------------------------------------------------------

  @doc """
  Verifies a complete webhook request: signature + optional timestamp freshness.

  Dispatches to the appropriate verification mode based on the profile.
  Returns `{:ok, payload}` with the decoded JSON payload on success.

  ## Options

  - `:now` — override current time for timestamp validation (epoch seconds)
  - `:delivery_id` — explicit delivery ID (overrides replay ID header extraction)
  - `:seen_delivery_ids` — list of previously seen delivery IDs for replay check
  """
  @spec verify_request(String.t(), map(), String.t() | nil, VerificationProfile.t(), keyword()) ::
          {:ok, map()} | {:error, Error.error()}
  def verify_request(body, headers, secret, %VerificationProfile{} = profile, opts \\ []) do
    parsed = parse_headers(headers, profile)

    with :ok <- verify_by_mode(body, parsed.signature, secret, profile),
         :ok <- maybe_verify_timestamp(parsed.timestamp, profile, opts),
         {:ok, payload} <- decode_body(body) do
      {:ok, payload}
    end
  end

  @doc """
  Verifies and returns a full `WebhookDelivery` struct.

  This is the highest-level verification entry point. It verifies the
  signature (dispatched by mode), decodes the body, extracts the replay
  ID from headers when `replay_id_header` is configured, and wraps the
  result in a `Jido.Connect.WebhookDelivery` with normalized metadata.

  ## Options

  - `:now` — override current time for timestamp validation (epoch seconds)
  - `:delivery_id` — explicit delivery ID (overrides replay ID header extraction)
  - `:seen_delivery_ids` — list of previously seen delivery IDs for replay check
  - `:event` — event type to attach to the delivery
  - `:source` — source URI to attach to the delivery
  """
  @spec verify_delivery(String.t(), map(), String.t() | nil, VerificationProfile.t(), keyword()) ::
          {:ok, WebhookDelivery.t()} | {:error, Error.error()}
  def verify_delivery(body, headers, secret, %VerificationProfile{} = profile, opts \\ []) do
    parsed = parse_headers(headers, profile)

    delivery_id = resolve_delivery_id(parsed.replay_id, opts)
    seen_delivery_ids = Keyword.get(opts, :seen_delivery_ids, [])

    with :ok <- verify_by_mode(body, parsed.signature, secret, profile),
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
               signature: redact_signature(parsed.signature),
               timestamp: parsed.timestamp,
               replay_id: delivery_id,
               profile: %{
                 mode: profile.mode,
                 signature_header: profile.signature_header,
                 timestamp_header: profile.timestamp_header,
                 digest_prefix: profile.digest_prefix,
                 replay_id_header: profile.replay_id_header
               }
             }
           }) do
      {:ok, delivery}
    end
  end

  # ---------------------------------------------------------------------------
  # Replay / dedup helpers
  # ---------------------------------------------------------------------------

  @doc """
  Checks whether a delivery ID has been seen before (replay protection).
  """
  @spec duplicate?(String.t() | nil, [String.t()]) :: boolean()
  def duplicate?(delivery_id, seen_delivery_ids) do
    CoreWebhook.duplicate?(delivery_id, seen_delivery_ids)
  end

  @doc """
  Extracts a replay/delivery ID from the configured header in `headers`.

  Returns `nil` when `replay_id_header` is not configured or the header
  is absent.
  """
  @spec extract_replay_id(map(), VerificationProfile.t()) :: String.t() | nil
  def extract_replay_id(headers, %VerificationProfile{} = profile) when is_map(headers) do
    if profile.replay_id_header do
      CoreWebhook.header(headers, profile.replay_id_header)
    else
      nil
    end
  end

  # ---------------------------------------------------------------------------
  # Redacted error details
  # ---------------------------------------------------------------------------

  @doc """
  Converts a verification error into a redacted map safe for transport and
  telemetry.

  Strips all secrets, tokens, signatures, and credential values. Returns a
  map with `:type`, `:message`, `:reason`, and a sanitized `:details` map.
  """
  @spec redacted_error(Error.error()) :: map()
  def redacted_error(error) do
    map = Error.to_map(error)
    # Ensure the top-level details are also sanitized (belt + suspenders)
    %{map | details: Sanitizer.sanitize(Map.get(map, :details, %{}), :transport)}
  end

  # ---------------------------------------------------------------------------
  # Internal helpers
  # ---------------------------------------------------------------------------

  defp resolve_delivery_id(replay_id_from_header, opts) do
    Keyword.get(opts, :delivery_id, replay_id_from_header)
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

  defp redact_signature(nil), do: nil
  defp redact_signature(_sig), do: "[redacted]"
end
