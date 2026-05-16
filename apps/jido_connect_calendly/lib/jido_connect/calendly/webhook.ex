defmodule Jido.Connect.Calendly.Webhook do
  @moduledoc """
  Pure helpers for Calendly webhook event verification and normalization.

  Calendly webhooks deliver signed JSON payloads to a configured callback URL.
  The payload includes an `event` field (e.g. `"invitee.created"` or
  `"invitee.canceled"`) and a `payload` object with the resource data.

  ## Supported Events

  **Invitee events**:

  - `invitee.created` — a new invitee was created (booking confirmed)
  - `invitee.canceled` — an invitee was canceled

  This module does **not** store or expose the webhook signing secret or any
  access tokens. Verification receives a pre-computed HMAC digest from the
  host layer.
  """

  alias Jido.Connect.{Data, Error}

  @supported_invitee_events ~w(invitee.created invitee.canceled)

  @doc """
  Returns the list of supported Calendly webhook invitee event types.
  """
  @spec supported_events() :: [String.t()]
  def supported_events, do: @supported_invitee_events

  @doc """
  Verifies the Calendly webhook signature.

  Calendly signs webhook payloads with an HMAC-SHA256 hex digest of the raw
  request body using the webhook's signing key. The signature is sent in the
  `Calendly-Webhook-Signature` header.

  Returns `:ok` when the computed HMAC-SHA256 hex digest matches the
  `signature`, or an error otherwise. The host is responsible for computing
  `computed` from the raw body and the webhook signing key; neither the key
  nor the raw body are passed through this module.
  """
  @spec verify_signature(computed :: String.t(), signature :: String.t()) ::
          :ok | {:error, Error.ProviderError.t()}
  def verify_signature(computed, signature)
      when is_binary(computed) and is_binary(signature) do
    if secure_compare?(computed, signature) do
      :ok
    else
      {:error,
       Error.provider("Calendly webhook signature verification failed",
         provider: :calendly,
         reason: :webhook_signature_mismatch
       )}
    end
  end

  def verify_signature(_computed, _signature) do
    {:error,
     Error.provider("Calendly webhook signature is missing",
       provider: :calendly,
       reason: :webhook_signature_missing
     )}
  end

  @doc """
  Computes the HMAC-SHA256 hex digest for a raw body and signing key.

  This is a convenience function for hosts that have the key available at
  verification time. Do not log or expose the signing key.
  """
  @spec compute_signature(raw_body :: String.t(), signing_key :: String.t()) :: String.t()
  def compute_signature(raw_body, signing_key)
      when is_binary(raw_body) and is_binary(signing_key) do
    :crypto.mac(:hmac, :sha256, signing_key, raw_body)
    |> Base.encode16(case: :lower)
  end

  @doc """
  Normalizes a Calendly webhook event payload into a signal map.

  Calendly webhook payloads contain an `event` field
  (e.g. `"invitee.created"`), a `time` field with an ISO 8601 timestamp,
  and a `payload` object with resource details.

  Returns `{:ok, signal_map}` on success, or `{:error, _}` on failure.
  """
  @spec normalize_event(map()) :: {:ok, map()} | {:error, Error.ProviderError.t()}
  def normalize_event(%{"event" => event, "payload" => payload} = delivery)
      when event in @supported_invitee_events and is_map(payload) do
    signal =
      %{
        event_type: event,
        change_type: change_type(event),
        invitee_uri: Data.get(payload, "uri"),
        invitee_email: Data.get(payload, "email"),
        invitee_name: Data.get(payload, "name"),
        invitee_status: Data.get(payload, "status"),
        invitee_timezone: Data.get(payload, "timezone"),
        event_uri: Data.get(payload, "event"),
        new_invitee_uri: Data.get(payload, "new_invitee"),
        old_invitee_uri: Data.get(payload, "old_invitee"),
        canceled_by: Data.get(payload, "canceled_by"),
        cancellation_reason: Data.get(payload, "cancellation_reason"),
        reschedule_reason: Data.get(payload, "reschedule_reason"),
        reschedule_url: Data.get(payload, "reschedule_url"),
        cancel_url: Data.get(payload, "cancel_url"),
        questions_and_answers: Data.get(payload, "questions_and_answers", []),
        event_type_uri: Data.get(payload, "event_type"),
        event_type_name: Data.get(payload, "event_type_name"),
        organization_uri: Data.get(payload, "organization"),
        created_at: Data.get(payload, "created_at"),
        updated_at: Data.get(payload, "updated_at"),
        time: Data.get(delivery, "time")
      }
      |> Data.compact()

    {:ok, signal}
  end

  def normalize_event(%{"event" => event}) when event not in @supported_invitee_events do
    {:error,
     Error.provider("Unsupported Calendly webhook event type",
       provider: :calendly,
       reason: :unsupported_webhook_event,
       details: %{event: event}
     )}
  end

  def normalize_event(%{"event" => event, "payload" => payload})
      when not is_map(payload) do
    {:error,
     Error.provider("Calendly webhook event payload is invalid",
       provider: :calendly,
       reason: :invalid_webhook_event,
       details: %{event: event}
     )}
  end

  def normalize_event(_payload) do
    {:error,
     Error.provider("Calendly webhook event payload is invalid",
       provider: :calendly,
       reason: :invalid_webhook_event
     )}
  end

  @doc """
  Normalizes a batch of Calendly webhook events.

  Returns `{:ok, signals}` with all successfully normalized events,
  or `{:error, _}` if any event is invalid.
  """
  @spec normalize_events([map()]) :: {:ok, [map()]} | {:error, Error.ProviderError.t()}
  def normalize_events(events) when is_list(events) do
    events
    |> Enum.reduce_while({:ok, []}, fn event, {:ok, acc} ->
      case normalize_event(event) do
        {:ok, signal} -> {:cont, {:ok, [signal | acc]}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, signals} -> {:ok, Enum.reverse(signals)}
      {:error, error} -> {:error, error}
    end
  end

  def normalize_events(_events) do
    {:error,
     Error.provider("Calendly webhook events payload must be a list",
       provider: :calendly,
       reason: :invalid_webhook_events
     )}
  end

  @doc "Extracts the invitee URI from a Calendly webhook event payload."
  @spec invitee_uri(map()) :: String.t() | nil
  def invitee_uri(%{"payload" => %{"uri" => uri}}), do: uri
  def invitee_uri(_payload), do: nil

  defp change_type("invitee.created"), do: "created"
  defp change_type("invitee.canceled"), do: "canceled"
  defp change_type(_), do: "unknown"

  # Constant-time string comparison to prevent timing attacks.
  defp secure_compare?(left, right) when byte_size(left) != byte_size(right), do: false

  defp secure_compare?(left, right) do
    left
    |> :binary.bin_to_list()
    |> Enum.zip(:binary.bin_to_list(right))
    |> Enum.reduce(0, fn {a, b}, acc -> Bitwise.bxor(a, b) + acc end) == 0
  end
end
