defmodule Jido.Connect.HubSpot.Webhook do
  @moduledoc """
  Pure helpers for HubSpot webhook event verification and normalization.

  HubSpot app webhooks deliver signed JSON payloads to a configured URL.
  The signature is an HMAC-SHA256 of the raw request body using the
  app's client secret. Hosts verify the signature before using these
  helpers to normalize the accepted delivery into trigger signals.

  This module does **not** store or expose the client secret. Verification
  receives a pre-computed HMAC digest from the host layer.
  """

  alias Jido.Connect.{Data, Error}

  @doc """
  Verifies the HubSpot webhook signature.

  Returns `:ok` when the computed HMAC-SHA256 hex digest matches the
  `signature`, or an error otherwise. The host is responsible for
  computing `computed` from the raw body and the app client secret;
  neither the secret nor the raw body are passed through this module.
  """
  @spec verify_signature(computed :: String.t(), signature :: String.t()) ::
          :ok | {:error, Error.ProviderError.t()}
  def verify_signature(computed, signature)
      when is_binary(computed) and is_binary(signature) do
    if secure_compare?(computed, signature) do
      :ok
    else
      {:error,
       Error.provider("HubSpot webhook signature verification failed",
         provider: :hubspot,
         reason: :webhook_signature_mismatch
       )}
    end
  end

  def verify_signature(_computed, _signature) do
    {:error,
     Error.provider("HubSpot webhook signature is missing",
       provider: :hubspot,
       reason: :webhook_signature_missing
     )}
  end

  @doc """
  Computes the HMAC-SHA256 hex digest for a raw body and client secret.

  This is a convenience function for hosts that have the secret available
  at verification time. Do not log or expose the secret.
  """
  @spec compute_signature(raw_body :: String.t(), client_secret :: String.t()) :: String.t()
  def compute_signature(raw_body, client_secret)
      when is_binary(raw_body) and is_binary(client_secret) do
    :crypto.mac(:hmac, :sha256, client_secret, raw_body)
    |> Base.encode16(case: :lower)
  end

  @doc """
  Normalizes a single HubSpot webhook event payload into a signal map.

  HubSpot webhook events carry:
    - `eventId` — unique event identifier
    - `subscriptionId` — the subscription that matched
    - `portalId` — the HubSpot account (portal) ID
    - `objectId` — the CRM object that changed
    - `eventType` — e.g. `contact.creation`, `deal.propertyChange`
    - `propertyValue` — new property value (for `propertyChange` events)
    - `propertyName` — changed property name (for `propertyChange` events)
    - `changeSource` — what caused the change
    - `occurredAt` — epoch millis timestamp
    - `appId` — the HubSpot app ID
  """
  @spec normalize_event(map()) :: {:ok, map()} | {:error, Error.ProviderError.t()}
  def normalize_event(payload) when is_map(payload) do
    object_type = object_type(payload)
    event_type = Data.get(payload, "eventType")
    object_id = Data.get(payload, "objectId")

    if is_nil(object_id) or object_id == "" do
      {:error,
       Error.provider("HubSpot webhook event missing objectId",
         provider: :hubspot,
         reason: :invalid_webhook_event,
         details: %{event_type: event_type}
       )}
    else
      signal =
        %{
          event_id: Data.get(payload, "eventId"),
          subscription_id: Data.get(payload, "subscriptionId"),
          portal_id: Data.get(payload, "portalId"),
          object_id: to_string(object_id),
          object_type: object_type,
          event_type: event_type,
          change_type: change_type(event_type),
          property_name: Data.get(payload, "propertyName"),
          property_value: Data.get(payload, "propertyValue"),
          change_source: Data.get(payload, "changeSource"),
          occurred_at: occurred_at(payload),
          app_id: Data.get(payload, "appId")
        }
        |> Data.compact()

      {:ok, signal}
    end
  end

  def normalize_event(_payload) do
    {:error,
     Error.provider("HubSpot webhook event payload is invalid",
       provider: :hubspot,
       reason: :invalid_webhook_event
     )}
  end

  @doc """
  Normalizes a batch of HubSpot webhook events.

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
     Error.provider("HubSpot webhook events payload must be a list",
       provider: :hubspot,
       reason: :invalid_webhook_events
     )}
  end

  @doc "Extracts the object type from a HubSpot webhook event."
  @spec object_type(map()) :: String.t() | nil
  def object_type(%{"eventType" => "contact." <> _}), do: "contact"
  def object_type(%{"eventType" => "company." <> _}), do: "company"
  def object_type(%{"eventType" => "deal." <> _}), do: "deal"
  def object_type(%{"eventType" => "ticket." <> _}), do: "ticket"
  def object_type(_payload), do: nil

  @doc "Converts HubSpot epoch-millis `occurredAt` to ISO 8601."
  @spec occurred_at(map()) :: String.t() | nil
  def occurred_at(%{"occurredAt" => epoch}) when is_integer(epoch) do
    DateTime.from_unix!(epoch, :millisecond) |> DateTime.to_iso8601()
  end

  def occurred_at(%{"occurredAt" => epoch}) when is_binary(epoch) do
    case Integer.parse(epoch) do
      {int, _} -> DateTime.from_unix!(int, :millisecond) |> DateTime.to_iso8601()
      :error -> nil
    end
  end

  def occurred_at(_payload), do: nil

  defp change_type("contact.creation"), do: "created"
  defp change_type("contact.deletion"), do: "deleted"
  defp change_type("contact.propertyChange"), do: "updated"
  defp change_type("company.creation"), do: "created"
  defp change_type("company.deletion"), do: "deleted"
  defp change_type("company.propertyChange"), do: "updated"
  defp change_type("deal.creation"), do: "created"
  defp change_type("deal.deletion"), do: "deleted"
  defp change_type("deal.propertyChange"), do: "updated"
  defp change_type("ticket.creation"), do: "created"
  defp change_type("ticket.deletion"), do: "deleted"
  defp change_type("ticket.propertyChange"), do: "updated"
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
