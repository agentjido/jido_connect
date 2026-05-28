defmodule Jido.Connect.Google.Drive.Webhook do
  @moduledoc """
  Pure helpers for Google Drive push notification normalization.

  Drive push notifications put the stable event metadata in `X-Goog-*` headers.
  Hosts verify the channel token and HTTPS delivery before using these helpers to
  turn the accepted delivery into the trigger signal shape.
  """

  alias Jido.Connect.{Data, Error, WebhookDelivery}
  alias Jido.Connect.Webhook, as: CoreWebhook

  @required_headers %{
    channel_id: "x-goog-channel-id",
    message_number: "x-goog-message-number",
    resource_id: "x-goog-resource-id",
    resource_state: "x-goog-resource-state",
    resource_uri: "x-goog-resource-uri"
  }

  @header_keys %{
    channel_id: "x-goog-channel-id",
    channel_token: "x-goog-channel-token",
    channel_expiration: "x-goog-channel-expiration",
    resource_id: "x-goog-resource-id",
    resource_uri: "x-goog-resource-uri",
    resource_state: "x-goog-resource-state",
    message_number: "x-goog-message-number",
    changed: "x-goog-changed"
  }

  @doc "Extracts normalized Google Drive push notification headers."
  def parse_headers(headers) when is_map(headers) or is_list(headers) do
    Map.new(@header_keys, fn {key, header_name} -> {key, header(headers, header_name)} end)
  end

  @doc "Verifies an optional channel token using constant-time comparison."
  def verify_token(headers, expected_token)

  def verify_token(_headers, expected_token) when expected_token in [nil, ""] do
    {:error,
     Error.auth("Google Drive webhook expected channel token is required",
       reason: :missing_expected_token
     )}
  end

  def verify_token(headers, expected_token) when is_binary(expected_token) do
    token = headers |> parse_headers() |> Map.get(:channel_token)

    cond do
      token in [nil, ""] ->
        {:error,
         Error.auth("Google Drive webhook channel token is required", reason: :missing_token)}

      Jido.Connect.Security.secure_compare?(token, expected_token) ->
        :ok

      true ->
        {:error,
         Error.auth("Google Drive webhook channel token is invalid", reason: :invalid_token)}
    end
  end

  @doc "Builds a normalized provider-neutral delivery from Google Drive headers."
  def normalize_delivery(headers, body \\ nil, opts \\ [])
      when is_map(headers) or is_list(headers) do
    headers = header_map(headers)
    parsed = parse_headers(headers)
    delivery_id = delivery_id(parsed)

    attrs = %{
      provider: :google_drive,
      event: parsed.resource_state,
      delivery_id: delivery_id,
      received_at: Keyword.get(opts, :received_at, DateTime.utc_now()),
      signature_state: Keyword.get(opts, :signature_state, :unverified),
      duplicate?: CoreWebhook.duplicate?(delivery_id, Keyword.get(opts, :seen_delivery_ids, [])),
      source: "google_drive_push",
      headers: headers,
      payload: decode_body(body),
      metadata: %{
        channel_id: parsed.channel_id,
        channel_token_present: present?(parsed.channel_token),
        channel_expiration: parsed.channel_expiration,
        resource_id: parsed.resource_id,
        resource_uri: parsed.resource_uri,
        resource_state: parsed.resource_state,
        message_number: parsed.message_number,
        changed: changed_values(parsed.changed)
      }
    }

    with {:ok, delivery} <- WebhookDelivery.new(attrs) do
      {:ok, WebhookDelivery.put_signal(delivery, signal_from_headers(parsed, delivery))}
    end
  end

  @doc "Verifies the optional token and returns a normalized delivery."
  def verify_delivery(headers, expected_token, opts \\ []) do
    with :ok <- verify_token(headers, expected_token),
         {:ok, delivery} <- normalize_delivery(headers, Keyword.get(opts, :body), opts) do
      {:ok, %{delivery | signature_state: :verified}}
    end
  end

  @doc "Normalizes a webhook delivery into a Drive file changed signal."
  @spec normalize_signal(WebhookDelivery.t() | map()) ::
          {:ok, map()} | {:error, Error.ProviderError.t()}
  def normalize_signal(%WebhookDelivery{headers: headers, payload: payload} = delivery) do
    with {:ok, signal} <- normalize_channel_notification(headers, payload) do
      {:ok, Map.put(signal, :delivery, delivery_metadata(delivery))}
    end
  end

  def normalize_signal(%{"headers" => headers} = delivery) do
    normalize_channel_notification(headers, Data.get(delivery, "payload"))
  end

  def normalize_signal(%{headers: headers} = delivery) do
    normalize_channel_notification(headers, Data.get(delivery, :payload))
  end

  def normalize_signal(headers) when is_map(headers) or is_list(headers) do
    normalize_channel_notification(headers, nil)
  end

  @doc "Normalizes Google Drive channel notification headers."
  @spec normalize_channel_notification(map() | list(), term()) ::
          {:ok, map()} | {:error, Error.ProviderError.t()}
  def normalize_channel_notification(headers, payload \\ nil) do
    case missing_required_headers(headers) do
      [] ->
        signal =
          %{
            channel_id: header(headers, "x-goog-channel-id"),
            message_number: header(headers, "x-goog-message-number"),
            resource_id: header(headers, "x-goog-resource-id"),
            resource_uri: header(headers, "x-goog-resource-uri"),
            resource_state: header(headers, "x-goog-resource-state"),
            channel_token: header(headers, "x-goog-channel-token"),
            channel_expiration: header(headers, "x-goog-channel-expiration"),
            changed: changed_values(header(headers, "x-goog-changed")),
            file_id: file_id_from_resource_uri(header(headers, "x-goog-resource-uri")),
            payload_kind: payload_kind(payload),
            resource_changed: resource_changed?(header(headers, "x-goog-resource-state"))
          }

        {:ok, Data.compact(signal)}

      missing ->
        {:error,
         Error.provider("Google Drive channel notification headers are invalid",
           provider: :google,
           reason: :invalid_drive_channel_headers,
           details: %{missing_headers: missing}
         )}
    end
  end

  defp missing_required_headers(headers) do
    @required_headers
    |> Map.values()
    |> Enum.filter(fn name -> blank?(header(headers, name)) end)
  end

  defp signal_from_headers(parsed, %WebhookDelivery{} = delivery) do
    %{
      channel_id: parsed.channel_id,
      channel_token_present: present?(parsed.channel_token),
      channel_expiration: parsed.channel_expiration,
      resource_id: parsed.resource_id,
      resource_uri: parsed.resource_uri,
      resource_state: parsed.resource_state,
      message_number: parsed.message_number,
      changed: changed_values(parsed.changed),
      file_id: file_id_from_resource_uri(parsed.resource_uri),
      resource_changed: resource_changed?(parsed.resource_state),
      delivery: %{
        provider: delivery.provider,
        event: delivery.event,
        id: delivery.delivery_id,
        duplicate?: delivery.duplicate?,
        received_at: delivery.received_at
      }
    }
    |> Data.compact()
  end

  defp delivery_id(%{channel_id: channel_id, message_number: message_number})
       when is_binary(channel_id) and is_binary(message_number),
       do: "#{channel_id}:#{message_number}"

  defp delivery_id(%{channel_id: channel_id}) when is_binary(channel_id), do: channel_id
  defp delivery_id(_parsed), do: nil

  defp header(headers, name) when is_map(headers) or is_list(headers) do
    headers
    |> header_map()
    |> CoreWebhook.header(name)
    |> header_value()
    |> trim()
  end

  defp header(_headers, _name), do: nil

  defp header_map(headers) when is_map(headers), do: headers
  defp header_map(headers) when is_list(headers), do: Map.new(headers)

  defp header_value([value | _rest]), do: value
  defp header_value(value), do: value

  defp trim(value) when is_binary(value), do: String.trim(value)
  defp trim(value), do: value

  defp present?(value), do: value not in [nil, ""]

  defp changed_values(value) when is_binary(value) do
    value
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp changed_values(_value), do: []

  defp file_id_from_resource_uri(uri) when is_binary(uri) do
    case Regex.run(~r{/files/([^/?#]+)}, uri) do
      [_match, file_id] -> URI.decode(file_id)
      _no_match -> nil
    end
  end

  defp file_id_from_resource_uri(_uri), do: nil

  defp payload_kind(%{"kind" => kind}) when is_binary(kind), do: kind
  defp payload_kind(%{kind: kind}) when is_binary(kind), do: kind
  defp payload_kind(_payload), do: nil

  defp resource_changed?("sync"), do: false
  defp resource_changed?(state) when is_binary(state), do: true
  defp resource_changed?(_state), do: false

  defp blank?(value), do: value in [nil, ""]

  defp delivery_metadata(%WebhookDelivery{} = delivery) do
    Data.compact(%{
      provider: delivery.provider,
      event: delivery.event,
      id: delivery.delivery_id,
      duplicate?: delivery.duplicate?,
      received_at: delivery.received_at
    })
  end

  defp decode_body(nil), do: nil
  defp decode_body(""), do: nil

  defp decode_body(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> decoded
      {:error, _error} -> body
    end
  end

  defp decode_body(body), do: body
end
