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
  """

  alias Jido.Connect.{Data, Error}
  alias Jido.Connect.Jira.ADFText
  alias Jido.Connect.Jira.Webhook.Verification

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
  `comment_created`, `comment_updated`).

  The payload structure varies by event type:

  - **Issue events**: contain an `issue` object with key, fields, and
    optional `changelog`.
  - **Comment events**: contain a `comment` object and an `issue` object
    providing context.

  `comment_body` comes from `Jido.Connect.Jira.ADFText`: an ADF body is
  rendered with the shared projection in `:degrade` mode and
  `comment_body_unsupported_nodes` lists the skipped node and mark types; a
  plain-string body, as administrator webhooks send it, passes through with
  an empty list. A comment body that is not valid ADF fails the event with
  `:invalid_webhook_event`.

  Returns `{:ok, signal_map}` on success, or `{:error, _}` on failure.
  """
  @spec normalize_event(map()) :: {:ok, map()} | {:error, Error.ProviderError.t()}
  def normalize_event(%{"webhookEvent" => event_type} = payload)
      when event_type in @supported_issue_events do
    issue_data = Data.get(payload, "issue")

    if is_nil(issue_data) or not is_map(issue_data) do
      {:error,
       Error.provider("Jira webhook event missing issue payload",
         provider: :jira,
         reason: :invalid_webhook_event,
         details: %{event_type: event_type}
       )}
    else
      fields = Data.get(issue_data, "fields") || %{}

      signal =
        %{
          event_type: event_type,
          change_type: issue_change_type(event_type),
          issue_id: Data.get(issue_data, "id"),
          issue_key: Data.get(issue_data, "key"),
          project_key: get_in(fields, ["project", "key"]),
          project_name: get_in(fields, ["project", "name"]),
          summary: Data.get(fields, "summary"),
          issue_type_name: get_in(fields, ["issuetype", "name"]),
          status_name: get_in(fields, ["status", "name"]),
          priority_name: get_in(fields, ["priority", "name"]),
          labels: Data.get(fields, "labels", []),
          assignee_id: get_in(fields, ["assignee", "accountId"]),
          assignee_name: get_in(fields, ["assignee", "displayName"]),
          reporter_id: get_in(fields, ["reporter", "accountId"]),
          reporter_name: get_in(fields, ["reporter", "displayName"]),
          created_at: Data.get(fields, "created"),
          updated_at: Data.get(fields, "updated"),
          changelog: normalize_changelog(Data.get(payload, "changelog")),
          webhook_id: Data.get(payload, "webhookID"),
          timestamp: Data.get(payload, "timestamp")
        }
        |> Data.compact()

      {:ok, signal}
    end
  end

  def normalize_event(%{"webhookEvent" => event_type} = payload)
      when event_type in @supported_comment_events do
    comment_data = Data.get(payload, "comment")
    issue_data = Data.get(payload, "issue")

    cond do
      is_nil(comment_data) or not is_map(comment_data) ->
        {:error,
         Error.provider("Jira webhook event missing comment payload",
           provider: :jira,
           reason: :invalid_webhook_event,
           details: %{event_type: event_type}
         )}

      is_nil(issue_data) or not is_map(issue_data) ->
        {:error,
         Error.provider("Jira webhook event missing issue context",
           provider: :jira,
           reason: :invalid_webhook_event,
           details: %{event_type: event_type}
         )}

      true ->
        comment_signal(event_type, payload, comment_data, issue_data)
    end
  end

  def normalize_event(%{"webhookEvent" => event_type}) do
    {:error,
     Error.provider("Unsupported Jira webhook event type",
       provider: :jira,
       reason: :unsupported_webhook_event,
       details: %{event_type: event_type}
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
  def issue_change_type("jira:issue_created"), do: "created"
  def issue_change_type("jira:issue_updated"), do: "updated"
  def issue_change_type(_), do: "unknown"

  @doc "Returns the change type for a comment event type."
  @spec comment_change_type(String.t()) :: String.t()
  def comment_change_type("comment_created"), do: "created"
  def comment_change_type("comment_updated"), do: "updated"
  def comment_change_type(_), do: "unknown"

  @doc "Converts Jira epoch-millis `timestamp` to ISO 8601."
  @spec timestamp_to_iso8601(integer() | String.t() | nil) :: String.t() | nil
  def timestamp_to_iso8601(epoch) when is_integer(epoch) do
    DateTime.from_unix!(epoch, :millisecond) |> DateTime.to_iso8601()
  end

  def timestamp_to_iso8601(epoch) when is_binary(epoch) do
    case Integer.parse(epoch) do
      {int, _} -> DateTime.from_unix!(int, :millisecond) |> DateTime.to_iso8601()
      :error -> nil
    end
  end

  def timestamp_to_iso8601(_), do: nil

  defp normalize_changelog(nil), do: nil

  defp normalize_changelog(%{"items" => items}) when is_list(items) do
    %{
      items:
        Enum.map(items, fn item ->
          %{
            field: Data.get(item, "field"),
            field_type: Data.get(item, "fieldtype"),
            from: Data.get(item, "from"),
            from_string: Data.get(item, "fromString"),
            to: Data.get(item, "to"),
            to_string: Data.get(item, "toString")
          }
          |> Data.compact()
        end)
    }
    |> Data.compact()
  end

  defp normalize_changelog(_), do: nil

  defp comment_signal(event_type, payload, comment_data, issue_data) do
    case ADFText.project(Data.get(comment_data, "body")) do
      {:ok, body} ->
        signal =
          %{
            event_type: event_type,
            change_type: comment_change_type(event_type),
            comment_id: Data.get(comment_data, "id"),
            comment_body: ADFText.text(body),
            comment_body_unsupported_nodes: ADFText.unsupported_nodes(body),
            comment_created_at: Data.get(comment_data, "created"),
            comment_updated_at: Data.get(comment_data, "updated"),
            comment_author_id: get_in(comment_data, ["author", "accountId"]),
            comment_author_name: get_in(comment_data, ["author", "displayName"]),
            issue_id: Data.get(issue_data, "id"),
            issue_key: Data.get(issue_data, "key"),
            webhook_id: Data.get(payload, "webhookID"),
            timestamp: Data.get(payload, "timestamp")
          }
          |> Data.compact()

        {:ok, signal}

      {:error, %Error.ValidationError{reason: reason}} ->
        {:error,
         Error.provider("Jira webhook comment body is invalid",
           provider: :jira,
           reason: :invalid_webhook_event,
           details: %{event_type: event_type, field: "comment.body", adf_reason: reason}
         )}
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
