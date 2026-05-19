defmodule Jido.Connect.Asana.Webhook do
  @moduledoc """
  Pure helpers for Asana webhook event verification and normalization.

  Asana webhooks deliver signed payloads using an HMAC-SHA256 of the raw
  request body with the webhook's shared secret. Hosts verify the signature
  before using these helpers to normalize the accepted delivery into trigger
  signals.

  This module does **not** store or expose the shared secret. Verification
  receives a pre-computed HMAC digest from the host layer.
  """

  alias Jido.Connect.{Data, Error}

  @doc """
  Verifies the Asana webhook signature.

  Returns `:ok` when the computed HMAC-SHA256 hex digest matches the
  `signature` sent in the `X-Hook-Signature` header, or an error otherwise.
  The host is responsible for computing `computed` from the raw body and the
  webhook secret; neither the secret nor the raw body are passed through this
  module.
  """
  @spec verify_signature(computed :: String.t(), signature :: String.t()) ::
          :ok | {:error, Error.ProviderError.t()}
  def verify_signature(computed, signature)
      when is_binary(computed) and is_binary(signature) do
    if secure_compare?(computed, signature) do
      :ok
    else
      {:error,
       Error.provider("Asana webhook signature verification failed",
         provider: :asana,
         reason: :webhook_signature_mismatch
       )}
    end
  end

  def verify_signature(_computed, _signature) do
    {:error,
     Error.provider("Asana webhook signature is missing",
       provider: :asana,
       reason: :webhook_signature_missing
     )}
  end

  @doc """
  Computes the HMAC-SHA256 hex digest for a raw body and webhook secret.

  This is a convenience function for hosts that have the secret available
  at verification time. Do not log or expose the secret.
  """
  @spec compute_signature(raw_body :: String.t(), secret :: String.t()) :: String.t()
  def compute_signature(raw_body, secret)
      when is_binary(raw_body) and is_binary(secret) do
    :crypto.mac(:hmac, :sha256, secret, raw_body)
    |> Base.encode16(case: :lower)
  end

  @doc """
  Normalizes an Asana webhook event payload into a signal map.

  Asana webhook events carry:
    - `resource` — the resource that triggered the event (with `gid`)
    - `action` — the action that occurred (e.g. `"changed"`, `"added"`, `"deleted"`)
    - `parent` — optional parent resource context
    - `created_at` — ISO 8601 timestamp
    - `user` — the user who triggered the event (with `gid`)
  """
  @spec normalize_event(map()) :: {:ok, map()} | {:error, Error.ProviderError.t()}
  def normalize_event(payload) when is_map(payload) do
    resource = Data.get(payload, "resource", %{})
    resource_gid = Data.get(resource, "gid")
    action = Data.get(payload, "action")

    if is_nil(resource_gid) or resource_gid == "" do
      {:error,
       Error.provider("Asana webhook event missing resource gid",
         provider: :asana,
         reason: :invalid_webhook_event,
         details: %{action: action}
       )}
    else
      user = Data.get(payload, "user", %{})
      parent = Data.get(payload, "parent", %{})

      signal =
        %{
          resource_gid: resource_gid,
          resource_type: Data.get(resource, "resource_type"),
          resource_name: Data.get(resource, "name"),
          action: action,
          change_type: change_type(action),
          parent_gid: Data.get(parent, "gid"),
          parent_type: Data.get(parent, "resource_type"),
          user_gid: Data.get(user, "gid"),
          user_name: Data.get(user, "name"),
          occurred_at: Data.get(payload, "created_at")
        }
        |> Data.compact()

      {:ok, signal}
    end
  end

  def normalize_event(_payload) do
    {:error,
     Error.provider("Asana webhook event payload is invalid",
       provider: :asana,
       reason: :invalid_webhook_event
     )}
  end

  @doc """
  Normalizes a batch of Asana webhook events (the `events` array).

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
     Error.provider("Asana webhook events payload must be a list",
       provider: :asana,
       reason: :invalid_webhook_events
     )}
  end

  defp change_type("changed"), do: "updated"
  defp change_type("added"), do: "created"
  defp change_type("deleted"), do: "deleted"
  defp change_type("removed"), do: "deleted"
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
