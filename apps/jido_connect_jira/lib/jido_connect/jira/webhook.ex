defmodule Jido.Connect.Jira.Webhook do
  @moduledoc """
  Pure helpers for Jira webhook deliveries and their normalization into
  trigger signals.

  Jira Cloud administrator webhooks sign each delivery with
  `X-Hub-Signature: sha256=<hex>`, the hex HMAC-SHA256 of the raw request
  body under the webhook secret. `Jido.Connect.Jira.Webhook.Verification`
  checks that signature. `verify_delivery/4` delegates to it and returns a
  verified `Jido.Connect.WebhookDelivery` with the signal of
  `normalize_event/1`. The host keeps the secret; this module does not store
  or expose it.

  `verify_signature/2` and `compute_signature/2` are legacy helpers that
  compare a base64 digest. That format does not match the header Jira sends.

  ## Supported Events

  - `jira:issue_created` — a new issue was created
  - `jira:issue_updated` — an existing issue was updated
  - `comment_created` — a comment was added to an issue
  - `comment_updated` — a comment was updated

  `Jido.Connect.Jira.Webhook.IssueSignal` and
  `Jido.Connect.Jira.Webhook.CommentSignal` describe the signal fields and
  their presence rules.
  """

  alias Jido.Connect.Error
  alias Jido.Connect.Jira.Webhook.{CommentSignal, IssueSignal, Payload, Verification}

  @supported_issue_events ~w(jira:issue_created jira:issue_updated)
  @supported_comment_events ~w(comment_created comment_updated)
  @supported_events @supported_issue_events ++ @supported_comment_events

  @doc """
  Returns the list of supported Jira webhook event types.
  """
  @spec supported_events() :: [String.t()]
  def supported_events, do: @supported_events

  @doc "See `Jido.Connect.Jira.Webhook.Verification.verify_delivery/4`."
  defdelegate verify_delivery(body, headers, secret, opts \\ []), to: Verification

  @doc """
  Legacy helper that compares two precomputed digests in constant time.

  Returns `:ok` when `computed` matches `signature`, or an error otherwise.
  It was written for a base64 digest from `compute_signature/2`, which does
  not match the `X-Hub-Signature` header of Jira administrator webhooks. Use
  `Jido.Connect.Jira.Webhook.Verification.verify_signature/3` for those.
  """
  @spec verify_signature(computed :: String.t(), signature :: String.t()) ::
          :ok | {:error, Error.ProviderError.t()}
  def verify_signature(computed, signature)
      when is_binary(computed) and is_binary(signature) do
    if secure_compare?(computed, signature) do
      :ok
    else
      {:error,
       Error.provider("Jira webhook signature verification failed",
         provider: :jira,
         reason: :webhook_signature_mismatch
       )}
    end
  end

  def verify_signature(_computed, _signature) do
    {:error,
     Error.provider("Jira webhook signature is missing",
       provider: :jira,
       reason: :webhook_signature_missing
     )}
  end

  @doc """
  Legacy helper that computes a base64 HMAC-SHA256 digest of a raw body.

  Jira administrator webhooks send a hex digest with a `sha256=` prefix
  instead; `Jido.Connect.Jira.Webhook.Verification` checks that format. Do
  not log or expose the secret.
  """
  @spec compute_signature(raw_body :: String.t(), shared_secret :: String.t()) :: String.t()
  def compute_signature(raw_body, shared_secret)
      when is_binary(raw_body) and is_binary(shared_secret) do
    :crypto.mac(:hmac, :sha256, shared_secret, raw_body)
    |> Base.encode64()
  end

  @doc """
  Normalizes a single Jira webhook event payload into a signal map.

  Jira webhook events carry a top-level `webhookEvent` field that
  identifies the event type (`jira:issue_created`, `jira:issue_updated`,
  `comment_created`, `comment_updated`). Issue events become
  `jira.issue.changed` signals through
  `Jido.Connect.Jira.Webhook.IssueSignal`, comment events become
  `jira.comment.changed` signals through
  `Jido.Connect.Jira.Webhook.CommentSignal`.

  Both signals carry `timestamp` as an ISO 8601 string and
  `matched_webhook_ids` only when the delivery names them; administrator
  webhooks do not.

  Returns `{:ok, signal_map}`, or `{:error, %Jido.Connect.Error.ProviderError{}}`:
  `:unsupported_webhook_event` for another event name and
  `:invalid_webhook_event` for a malformed payload. Malformed payloads never
  raise, and error details never hold payload values.
  """
  @spec normalize_event(term()) :: {:ok, map()} | {:error, Error.ProviderError.t()}
  def normalize_event(%{"webhookEvent" => event_type} = payload)
      when event_type in @supported_issue_events,
      do: IssueSignal.normalize(event_type, payload)

  def normalize_event(%{"webhookEvent" => event_type} = payload)
      when event_type in @supported_comment_events,
      do: CommentSignal.normalize(event_type, payload)

  def normalize_event(%{"webhookEvent" => event_type}) when is_binary(event_type) do
    {:error,
     Error.provider("Unsupported Jira webhook event type",
       provider: :jira,
       reason: :unsupported_webhook_event
     )}
  end

  def normalize_event(_payload) do
    {:error,
     Error.provider("Jira webhook event payload is invalid",
       provider: :jira,
       reason: :invalid_webhook_event
     )}
  end

  @doc """
  Normalizes a batch of Jira webhook events.

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
     Error.provider("Jira webhook events payload must be a list",
       provider: :jira,
       reason: :invalid_webhook_events
     )}
  end

  @doc "Extracts the issue key from a Jira webhook event payload."
  @spec issue_key(map()) :: String.t() | nil
  def issue_key(%{"issue" => %{"key" => key}}), do: key
  def issue_key(_payload), do: nil

  @doc "Returns the change type for an issue event type."
  @spec issue_change_type(String.t()) :: String.t()
  defdelegate issue_change_type(event_type), to: IssueSignal, as: :change_type

  @doc "Returns the change type for a comment event type."
  @spec comment_change_type(String.t()) :: String.t()
  defdelegate comment_change_type(event_type), to: CommentSignal, as: :change_type

  @doc """
  Converts Jira epoch-millis `timestamp` to ISO 8601.

  Returns `nil` for `nil`, for a value that is neither an integer nor a string
  of digits, and for an epoch outside the range of `DateTime`.
  """
  @spec timestamp_to_iso8601(term()) :: String.t() | nil
  def timestamp_to_iso8601(epoch) do
    case Payload.epoch_to_iso8601(epoch) do
      {:ok, iso8601} -> iso8601
      :error -> nil
    end
  end

  # Constant-time string comparison to prevent timing attacks.
  defp secure_compare?(left, right) when byte_size(left) != byte_size(right), do: false

  defp secure_compare?(left, right) do
    left
    |> :binary.bin_to_list()
    |> Enum.zip(:binary.bin_to_list(right))
    |> Enum.reduce(0, fn {a, b}, acc -> Bitwise.bxor(a, b) + acc end) == 0
  end
end
