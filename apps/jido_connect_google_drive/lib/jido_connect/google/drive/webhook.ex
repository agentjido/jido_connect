defmodule Jido.Connect.Google.Drive.Webhook do
  @moduledoc """
  Pure helpers for Google Drive push notification verification and normalization.

  Google Drive push notifications do not include an HMAC signature. Hosts should
  verify the channel id, resource id, and optional channel token against their
  own stored channel registration before accepting a delivery.
  """

  alias Jido.Connect.{Error, WebhookDelivery}
  alias Jido.Connect.Webhook, as: CoreWebhook

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
  def parse_headers(headers) when is_map(headers) do
    Map.new(@header_keys, fn {key, header} -> {key, CoreWebhook.header(headers, header)} end)
  end

  @doc "Verifies an optional channel token using constant-time comparison."
  def verify_token(headers, expected_token)

  def verify_token(_headers, expected_token) when expected_token in [nil, ""], do: :ok

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
  def normalize_delivery(headers, body \\ nil, opts \\ []) when is_map(headers) do
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
        channel_token: parsed.channel_token,
        channel_expiration: parsed.channel_expiration,
        resource_id: parsed.resource_id,
        resource_uri: parsed.resource_uri,
        resource_state: parsed.resource_state,
        message_number: parsed.message_number,
        changed: changed_fields(parsed.changed)
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

  defp signal_from_headers(parsed, %WebhookDelivery{} = delivery) do
    %{
      channel_id: parsed.channel_id,
      channel_token: parsed.channel_token,
      channel_expiration: parsed.channel_expiration,
      resource_id: parsed.resource_id,
      resource_uri: parsed.resource_uri,
      resource_state: parsed.resource_state,
      message_number: parsed.message_number,
      changed: changed_fields(parsed.changed),
      delivery: %{
        provider: delivery.provider,
        event: delivery.event,
        id: delivery.delivery_id,
        duplicate?: delivery.duplicate?,
        received_at: delivery.received_at
      }
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp delivery_id(%{channel_id: channel_id, message_number: message_number})
       when is_binary(channel_id) and is_binary(message_number),
       do: "#{channel_id}:#{message_number}"

  defp delivery_id(%{channel_id: channel_id}) when is_binary(channel_id), do: channel_id
  defp delivery_id(_parsed), do: nil

  defp changed_fields(nil), do: []

  defp changed_fields(value) when is_binary(value) do
    value
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
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
