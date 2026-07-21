defmodule Jido.Connect.Intercom.Webhook do
  @moduledoc """
  Pure helpers for Intercom webhook event verification and normalization.

  Intercom webhooks deliver signed JSON payloads to a configured URL.
  The signature is a hex-encoded HMAC-SHA256 of the raw request body
  using the app's webhook secret. Hosts verify the signature before
  using these helpers to normalize the accepted delivery into trigger
  signals.

  This module does **not** store or expose the webhook secret. Verification
  receives a pre-computed HMAC digest from the host layer.

  ## Supported Topics

  ### Conversation topics

  - `conversation.user.created` — a new conversation was started by a user
  - `conversation.admin.replied` — an admin replied to a conversation
  - `conversation.user.replied` — a user replied to a conversation
  - `conversation.admin.assigned` — a conversation was assigned
  - `conversation.admin.closed` — a conversation was closed

  ### Contact topics

  - `contact.created` — a new contact was created
  - `contact.updated` — a contact was updated
  - `contact.deleted` — a contact was deleted
  """

  alias Jido.Connect.{Data, Error}

  @conversation_topics ~w(
    conversation.user.created
    conversation.admin.replied
    conversation.user.replied
    conversation.admin.assigned
    conversation.admin.closed
  )

  @contact_topics ~w(
    contact.created
    contact.updated
    contact.deleted
  )

  @supported_topics @conversation_topics ++ @contact_topics

  @doc """
  Returns the list of supported Intercom webhook topics.
  """
  @spec supported_topics() :: [String.t()]
  def supported_topics, do: @supported_topics

  @doc """
  Returns the list of conversation-related webhook topics.
  """
  @spec conversation_topics() :: [String.t()]
  def conversation_topics, do: @conversation_topics

  @doc """
  Returns the list of contact-related webhook topics.
  """
  @spec contact_topics() :: [String.t()]
  def contact_topics, do: @contact_topics

  @doc """
  Verifies the Intercom webhook signature.

  Intercom signs webhook payloads with an HMAC-SHA256 hex digest sent
  in the `X-Hub-Signature` header. Returns `:ok` when the computed
  HMAC-SHA256 hex digest matches `signature`, or an error otherwise.

  The host is responsible for computing `computed` from the raw body
  and the webhook secret; neither the secret nor the raw body are
  passed through this module.
  """
  @spec verify_signature(computed :: String.t(), signature :: String.t()) ::
          :ok | {:error, Error.ProviderError.t()}
  def verify_signature(computed, signature)
      when is_binary(computed) and is_binary(signature) do
    if secure_compare?(computed, signature) do
      :ok
    else
      {:error,
       Error.provider("Intercom webhook signature verification failed",
         provider: :intercom,
         reason: :webhook_signature_mismatch
       )}
    end
  end

  def verify_signature(_computed, _signature) do
    {:error,
     Error.provider("Intercom webhook signature is missing",
       provider: :intercom,
       reason: :webhook_signature_missing
     )}
  end

  @doc """
  Computes the HMAC-SHA256 hex digest for a raw body and webhook secret.

  This is a convenience function for hosts that have the secret available
  at verification time. Do not log or expose the secret.
  """
  @spec compute_signature(raw_body :: String.t(), webhook_secret :: String.t()) :: String.t()
  def compute_signature(raw_body, webhook_secret)
      when is_binary(raw_body) and is_binary(webhook_secret) do
    :crypto.mac(:hmac, :sha256, webhook_secret, raw_body)
    |> Base.encode16(case: :lower)
  end

  @doc """
  Normalizes a single Intercom webhook notification payload into a signal map.

  Intercom webhook notifications carry:
    - `topic` — the event type (e.g. `conversation.user.created`, `contact.created`)
    - `delivery_id` — unique delivery identifier
    - `delivery_attempt` — attempt number
    - `created_at` — Unix timestamp
    - `app_id` — the Intercom app ID
    - `data.item` — the resource that changed (conversation or contact)

  Returns `{:ok, signal_map}` on success, or `{:error, _}` on failure.
  """
  @spec normalize_event(map()) :: {:ok, map()} | {:error, Error.ProviderError.t()}
  def normalize_event(%{"topic" => topic} = payload) when topic in @supported_topics do
    item = get_in(payload, ["data", "item"])

    signal =
      %{
        topic: topic,
        change_type: change_type(topic),
        delivery_id: Data.get(payload, "delivery_id"),
        delivery_attempt: Data.get(payload, "delivery_attempt"),
        created_at: Data.get(payload, "created_at"),
        app_id: Data.get(payload, "app_id")
      }
      |> merge_item_fields(topic, item)
      |> Data.compact()

    {:ok, signal}
  end

  def normalize_event(%{"topic" => topic}) do
    {:error,
     Error.provider("Unsupported Intercom webhook topic",
       provider: :intercom,
       reason: :unsupported_webhook_topic,
       details: %{topic: topic}
     )}
  end

  def normalize_event(_payload) do
    {:error,
     Error.provider("Intercom webhook event payload is invalid",
       provider: :intercom,
       reason: :invalid_webhook_event
     )}
  end

  @doc """
  Normalizes a batch of Intercom webhook events.

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
     Error.provider("Intercom webhook events payload must be a list",
       provider: :intercom,
       reason: :invalid_webhook_events
     )}
  end

  @doc "Converts a webhook topic to a change type."
  @spec change_type(String.t()) :: String.t()
  def change_type("conversation.user.created"), do: "created"
  def change_type("conversation.admin.replied"), do: "admin_replied"
  def change_type("conversation.user.replied"), do: "user_replied"
  def change_type("conversation.admin.assigned"), do: "assigned"
  def change_type("conversation.admin.closed"), do: "closed"
  def change_type("contact.created"), do: "created"
  def change_type("contact.updated"), do: "updated"
  def change_type("contact.deleted"), do: "deleted"
  def change_type(_), do: "unknown"

  @doc "Extracts the conversation ID from an Intercom webhook event payload."
  @spec conversation_id(map()) :: String.t() | nil
  def conversation_id(%{"data" => %{"item" => %{"type" => "conversation", "id" => id}}}), do: id
  def conversation_id(_payload), do: nil

  @doc "Extracts the contact ID from an Intercom webhook event payload."
  @spec contact_id(map()) :: String.t() | nil
  def contact_id(%{"data" => %{"item" => %{"type" => "contact", "id" => id}}}), do: id
  def contact_id(_payload), do: nil

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp merge_item_fields(signal, topic, item)
       when is_map(item) and topic in @conversation_topics do
    source = Data.get(item, "source") || %{}
    author = Data.get(source, "author") || %{}

    signal
    |> Map.put(:conversation_id, Data.get(item, "id"))
    |> Map.put(:conversation_state, Data.get(item, "state"))
    |> Map.put(:conversation_title, Data.get(item, "title") || Data.get(source, "subject"))
    |> Map.put(:conversation_body, Data.get(source, "body"))
    |> Map.put(:conversation_delivered_as, Data.get(source, "delivered_as"))
    |> Map.put(:author_id, Data.get(author, "id"))
    |> Map.put(:author_type, Data.get(author, "type"))
  end

  defp merge_item_fields(signal, topic, item) when is_map(item) and topic in @contact_topics do
    signal
    |> Map.put(:contact_id, Data.get(item, "id"))
    |> Map.put(:contact_name, Data.get(item, "name"))
    |> Map.put(:contact_email, Data.get(item, "email"))
  end

  defp merge_item_fields(signal, _topic, _item), do: signal

  # Constant-time string comparison to prevent timing attacks.
  defp secure_compare?(left, right) when byte_size(left) != byte_size(right), do: false

  defp secure_compare?(left, right) do
    left
    |> :binary.bin_to_list()
    |> Enum.zip(:binary.bin_to_list(right))
    |> Enum.reduce(0, fn {a, b}, acc -> Bitwise.bxor(a, b) + acc end) == 0
  end
end
