defmodule Jido.Connect.InboundWebhook.Normalizer do
  @moduledoc """
  Pure helpers for generic inbound webhook delivery normalization.

  After the host verifies an inbound webhook (signature, timestamp, replay ID),
  these helpers normalize the `WebhookDelivery` struct into the trigger signal
  shape, carrying headers, body, and query metadata in a provider-agnostic form.
  """

  alias Jido.Connect.{Data, WebhookDelivery}

  @doc """
  Normalizes a `WebhookDelivery` into the inbound delivery signal shape.

  Extracts headers, payload, delivery metadata, and any query parameters
  stored in the delivery metadata. Returns a compact map suitable for
  trigger signal emission.
  """
  @spec normalize_signal(WebhookDelivery.t()) :: {:ok, map()}
  def normalize_signal(%WebhookDelivery{} = delivery) do
    signal =
      %{
        delivery_id: delivery.delivery_id,
        event: delivery.event,
        source: delivery.source,
        duplicate?: delivery.duplicate?,
        headers: sanitize_headers(delivery.headers),
        payload: delivery.payload,
        query: query_metadata(delivery),
        metadata: delivery_metadata(delivery),
        delivery: delivery_summary(delivery)
      }
      |> Data.compact()

    {:ok, signal}
  end

  @doc """
  Extracts header metadata from a `WebhookDelivery`, sanitizing sensitive values.

  Returns a map of header names to values with any secrets or tokens redacted.
  """
  @spec extract_headers(WebhookDelivery.t()) :: map()
  def extract_headers(%WebhookDelivery{headers: headers}) when is_map(headers) do
    sanitize_headers(headers)
  end

  def extract_headers(%WebhookDelivery{}), do: %{}

  @doc """
  Extracts query parameters from delivery metadata (key `"query"`).

  Hosts store query string parameters in the delivery metadata before
  verification. Returns an empty map when absent.
  """
  @spec extract_query(WebhookDelivery.t()) :: map()
  def extract_query(%WebhookDelivery{metadata: %{query: query}}) when is_map(query), do: query
  def extract_query(%WebhookDelivery{metadata: %{"query" => query}}) when is_map(query), do: query
  def extract_query(%WebhookDelivery{}), do: %{}

  @doc """
  Builds a dedupe key from delivery metadata.

  Uses the delivery ID when present, or falls back to a composite of
  the event type and source.
  """
  @spec dedupe_key(WebhookDelivery.t()) :: String.t() | nil
  def dedupe_key(%WebhookDelivery{delivery_id: id}) when is_binary(id) and byte_size(id) > 0,
    do: id

  def dedupe_key(%WebhookDelivery{event: event, source: source})
      when is_binary(event) and is_binary(source),
      do: "#{event}:#{source}"

  def dedupe_key(%WebhookDelivery{}), do: nil

  @doc """
  Returns a JSON-safe public summary of the delivery for signal metadata.
  """
  @spec delivery_summary(WebhookDelivery.t()) :: map()
  def delivery_summary(%WebhookDelivery{} = delivery) do
    Data.compact(%{
      provider: delivery.provider,
      event: delivery.event,
      id: delivery.delivery_id,
      duplicate?: delivery.duplicate?,
      received_at: delivery.received_at,
      signature_state: delivery.signature_state
    })
  end

  # ---------------------------------------------------------------------------
  # Internal helpers
  # ---------------------------------------------------------------------------

  defp sanitize_headers(headers) when is_map(headers) do
    headers
    |> Enum.map(fn {key, value} ->
      {key, maybe_redact_header(key, value)}
    end)
    |> Map.new()
  end

  defp sanitize_headers(headers), do: headers

  @sensitive_header_patterns [
    ~r/signature/i,
    ~r/authorization/i,
    ~r/x-hub-signature/i,
    ~r/x-slack-signature/i,
    ~r/x-signature/i,
    ~r/cookie/i
  ]

  defp maybe_redact_header(key, value) when is_binary(key) and is_binary(value) do
    if Enum.any?(@sensitive_header_patterns, &Regex.match?(&1, key)) do
      "[redacted]"
    else
      value
    end
  end

  defp maybe_redact_header(_key, value), do: value

  defp query_metadata(%WebhookDelivery{} = delivery) do
    case extract_query(delivery) do
      q when q == %{} -> nil
      q -> q
    end
  end

  defp delivery_metadata(%WebhookDelivery{metadata: metadata}) when is_map(metadata) do
    metadata
    |> Map.drop(["query", "query"])
    |> Data.compact()
  end

  defp delivery_metadata(_metadata), do: %{}
end
