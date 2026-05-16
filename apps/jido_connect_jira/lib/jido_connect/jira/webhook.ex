defmodule Jido.Connect.Jira.Webhook do
  @moduledoc """
  Pure helpers for Jira webhook event verification and normalization.

  Jira webhooks deliver signed JSON payloads to a configured URL.
  The signature is a base64-encoded HMAC-SHA256 of the raw request body
  using the webhook's shared secret. Hosts verify the signature before
  using these helpers to normalize the accepted delivery into trigger
  signals.

  This module does **not** store or expose the shared secret. Verification
  receives a pre-computed HMAC digest from the host layer.

  ## Supported Events

  - `jira:issue_created` — a new issue was created
  - `jira:issue_updated` — an existing issue was updated
  - `comment_created` — a comment was added to an issue
  - `comment_updated` — a comment was updated
  """

  alias Jido.Connect.{Data, Error}

  @supported_issue_events ~w(jira:issue_created jira:issue_updated)
  @supported_comment_events ~w(comment_created comment_updated)
  @supported_events @supported_issue_events ++ @supported_comment_events

  @doc """
  Returns the list of supported Jira webhook event types.
  """
  @spec supported_events() :: [String.t()]
  def supported_events, do: @supported_events

  @doc """
  Verifies the Jira webhook signature.

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
  Normalizes a single Jira webhook event payload into a signal map.

  Jira webhook events carry a top-level `webhookEvent` field that
  identifies the event type (`jira:issue_created`, `jira:issue_updated`,
  `comment_created`, `comment_updated`).

  The payload structure varies by event type:

  - **Issue events**: contain an `issue` object with key, fields, and
    optional `changelog`.
  - **Comment events**: contain a `comment` object and an `issue` object
    providing context.

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
        signal =
          %{
            event_type: event_type,
            change_type: comment_change_type(event_type),
            comment_id: Data.get(comment_data, "id"),
            comment_body: normalize_comment_body(Data.get(comment_data, "body")),
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

  defp normalize_comment_body(%{"type" => "doc", "content" => content} = _adf)
       when is_list(content) do
    extract_text_from_adf(content)
    |> String.trim()
  end

  defp normalize_comment_body(text) when is_binary(text), do: text
  defp normalize_comment_body(_), do: nil

  defp extract_text_from_adf(nodes) when is_list(nodes) do
    Enum.map_join(nodes, "", &extract_text_from_adf/1)
  end

  defp extract_text_from_adf(%{"content" => content}) when is_list(content) do
    extract_text_from_adf(content)
  end

  defp extract_text_from_adf(%{"text" => text}) when is_binary(text), do: text
  defp extract_text_from_adf(_), do: ""

  # Constant-time string comparison to prevent timing attacks.
  defp secure_compare?(left, right) when byte_size(left) != byte_size(right), do: false

  defp secure_compare?(left, right) do
    left
    |> :binary.bin_to_list()
    |> Enum.zip(:binary.bin_to_list(right))
    |> Enum.reduce(0, fn {a, b}, acc -> Bitwise.bxor(a, b) + acc end) == 0
  end
end
