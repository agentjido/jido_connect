defmodule Jido.Connect.Zendesk.Webhook do
  @moduledoc """
  Pure helpers for Zendesk webhook event verification and normalization.

  Zendesk webhooks deliver signed JSON payloads to a configured URL.
  The signature is a base64-encoded HMAC-SHA256 of the raw request body
  using the webhook's shared secret. Hosts verify the signature before
  using these helpers to normalize the accepted delivery into trigger
  signals.

  This module does **not** store or expose the shared secret. Verification
  receives a pre-computed HMAC digest from the host layer.

  ## Supported Events

  - `Ticket Created` — a new ticket was created
  - `Ticket Updated` — an existing ticket was updated
  - `Comment Created` — a comment was added to a ticket
  - `Ticket Status Changed` — a ticket's status changed
  """

  alias Jido.Connect.{Data, Error}

  @supported_ticket_events ["Ticket Created", "Ticket Updated", "Ticket Status Changed"]
  @supported_comment_events ["Comment Created"]
  @supported_events @supported_ticket_events ++ @supported_comment_events

  @doc """
  Returns the list of supported Zendesk webhook event types.
  """
  @spec supported_events() :: [String.t()]
  def supported_events, do: @supported_events

  @doc """
  Verifies the Zendesk webhook signature.

  Returns `:ok` when the computed HMAC-SHA256 base64 digest matches the
  `signature`, or an error otherwise. The host is responsible for
  computing `computed` from the raw body and the webhook shared secret;
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
       Error.provider("Zendesk webhook signature verification failed",
         provider: :zendesk,
         reason: :webhook_signature_mismatch
       )}
    end
  end

  def verify_signature(_computed, _signature) do
    {:error,
     Error.provider("Zendesk webhook signature is missing",
       provider: :zendesk,
       reason: :webhook_signature_missing
     )}
  end

  @doc """
  Computes the HMAC-SHA256 base64 digest for a raw body and shared secret.

  This is a convenience function for hosts that have the secret available
  at verification time. Do not log or expose the secret.
  """
  @spec compute_signature(raw_body :: String.t(), shared_secret :: String.t()) :: String.t()
  def compute_signature(raw_body, shared_secret)
      when is_binary(raw_body) and is_binary(shared_secret) do
    :crypto.mac(:hmac, :sha256, shared_secret, raw_body)
    |> Base.encode64()
  end

  @doc """
  Normalizes a single Zendesk webhook event payload into a signal map.

  Zendesk webhook events carry:
    - `type` — event type (e.g. `Ticket Created`, `Comment Created`)
    - `id` — webhook invocation ID
    - `account_id` — Zendesk subdomain
    - `ticket` — the ticket context
    - `current` — current state of the resource
    - `previous` — previous state of the resource (for update events)

  Returns `{:ok, signal_map}` on success, or `{:error, _}` on failure.
  """
  @spec normalize_event(map()) :: {:ok, map()} | {:error, Error.ProviderError.t()}
  def normalize_event(%{"type" => event_type} = payload)
      when event_type in @supported_ticket_events do
    ticket_data = Data.get(payload, "ticket") || Data.get(payload, "current")
    previous_data = Data.get(payload, "previous")

    if is_nil(ticket_data) or not is_map(ticket_data) do
      {:error,
       Error.provider("Zendesk webhook event missing ticket payload",
         provider: :zendesk,
         reason: :invalid_webhook_event,
         details: %{event_type: event_type}
       )}
    else
      signal =
        %{
          event_type: event_type,
          change_type: ticket_change_type(event_type),
          ticket_id: Data.get(ticket_data, "id"),
          subject: Data.get(ticket_data, "subject"),
          status: Data.get(ticket_data, "status"),
          priority: Data.get(ticket_data, "priority"),
          type: Data.get(ticket_data, "type"),
          group_id: Data.get(ticket_data, "group_id"),
          assignee_id: Data.get(ticket_data, "assignee_id"),
          requester_id: Data.get(ticket_data, "requester_id"),
          organization_id: Data.get(ticket_data, "organization_id"),
          tags: Data.get(ticket_data, "tags", []),
          created_at: Data.get(ticket_data, "created_at"),
          updated_at: Data.get(ticket_data, "updated_at"),
          via: Data.get(ticket_data, "via"),
          previous: normalize_previous(previous_data),
          webhook_id: Data.get(payload, "id"),
          account_id: Data.get(payload, "account_id"),
          timestamp: Data.get(payload, "timestamp")
        }
        |> Data.compact()

      {:ok, signal}
    end
  end

  def normalize_event(%{"type" => "Comment Created"} = payload) do
    comment_data = Data.get(payload, "current")
    ticket_data = Data.get(payload, "ticket")

    cond do
      is_nil(comment_data) or not is_map(comment_data) ->
        {:error,
         Error.provider("Zendesk webhook event missing comment payload",
           provider: :zendesk,
           reason: :invalid_webhook_event,
           details: %{event_type: "Comment Created"}
         )}

      is_nil(ticket_data) or not is_map(ticket_data) ->
        {:error,
         Error.provider("Zendesk webhook event missing ticket context",
           provider: :zendesk,
           reason: :invalid_webhook_event,
           details: %{event_type: "Comment Created"}
         )}

      true ->
        signal =
          %{
            event_type: "Comment Created",
            change_type: "created",
            comment_id: Data.get(comment_data, "id"),
            comment_body: Data.get(comment_data, "body"),
            comment_html_body: Data.get(comment_data, "html_body"),
            comment_public: Data.get(comment_data, "public"),
            comment_author_id: Data.get(comment_data, "author_id"),
            ticket_id: Data.get(ticket_data, "id"),
            ticket_subject: Data.get(ticket_data, "subject"),
            webhook_id: Data.get(payload, "id"),
            account_id: Data.get(payload, "account_id"),
            timestamp: Data.get(payload, "timestamp")
          }
          |> Data.compact()

        {:ok, signal}
    end
  end

  def normalize_event(%{"type" => event_type}) do
    {:error,
     Error.provider("Unsupported Zendesk webhook event type",
       provider: :zendesk,
       reason: :unsupported_webhook_event,
       details: %{event_type: event_type}
     )}
  end

  def normalize_event(_payload) do
    {:error,
     Error.provider("Zendesk webhook event payload is invalid",
       provider: :zendesk,
       reason: :invalid_webhook_event
     )}
  end

  @doc """
  Normalizes a batch of Zendesk webhook events.

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
     Error.provider("Zendesk webhook events payload must be a list",
       provider: :zendesk,
       reason: :invalid_webhook_events
     )}
  end

  @doc "Extracts the ticket ID from a Zendesk webhook event payload."
  @spec ticket_id(map()) :: integer() | nil
  def ticket_id(%{"ticket" => %{"id" => id}}), do: id
  def ticket_id(%{"current" => %{"id" => id}}), do: id
  def ticket_id(_payload), do: nil

  @doc "Returns the change type for a ticket event type."
  @spec ticket_change_type(String.t()) :: String.t()
  def ticket_change_type("Ticket Created"), do: "created"
  def ticket_change_type("Ticket Updated"), do: "updated"
  def ticket_change_type("Ticket Status Changed"), do: "status_changed"
  def ticket_change_type(_), do: "unknown"

  # Constant-time string comparison to prevent timing attacks.
  defp secure_compare?(left, right) when byte_size(left) != byte_size(right), do: false

  defp secure_compare?(left, right) do
    left
    |> :binary.bin_to_list()
    |> Enum.zip(:binary.bin_to_list(right))
    |> Enum.reduce(0, fn {a, b}, acc -> Bitwise.bxor(a, b) + acc end) == 0
  end

  defp normalize_previous(nil), do: nil

  defp normalize_previous(data) when is_map(data) do
    %{
      status: Data.get(data, "status"),
      priority: Data.get(data, "priority"),
      assignee_id: Data.get(data, "assignee_id"),
      group_id: Data.get(data, "group_id"),
      updated_at: Data.get(data, "updated_at")
    }
    |> Data.compact()
  end

  defp normalize_previous(_), do: nil
end
