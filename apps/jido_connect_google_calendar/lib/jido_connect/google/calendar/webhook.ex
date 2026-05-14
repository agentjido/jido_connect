defmodule Jido.Connect.Google.Calendar.Webhook do
  @moduledoc """
  Pure helpers for Google Calendar push notification normalization.

  Calendar push notifications carry channel and resource state in `X-Goog-*`
  headers. Hosts verify the channel token and HTTPS delivery before using these
  helpers to turn the accepted delivery into a trigger signal.
  """

  alias Jido.Connect.{Data, Error, WebhookDelivery}

  @required_headers %{
    channel_id: "x-goog-channel-id",
    message_number: "x-goog-message-number",
    resource_id: "x-goog-resource-id",
    resource_state: "x-goog-resource-state",
    resource_uri: "x-goog-resource-uri"
  }

  @doc "Normalizes a webhook delivery into a Calendar channel signal."
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

  @doc "Normalizes Google Calendar channel notification headers."
  @spec normalize_channel_notification(map() | list(), term()) ::
          {:ok, map()} | {:error, Error.ProviderError.t()}
  def normalize_channel_notification(headers, payload \\ nil) do
    case missing_required_headers(headers) do
      [] ->
        resource_uri = header(headers, "x-goog-resource-uri")
        resource_state = header(headers, "x-goog-resource-state")

        signal =
          %{
            channel_id: header(headers, "x-goog-channel-id"),
            message_number: header(headers, "x-goog-message-number"),
            resource_id: header(headers, "x-goog-resource-id"),
            resource_uri: resource_uri,
            resource_state: resource_state,
            resource_type: resource_type(resource_uri),
            resource_changed: resource_changed?(resource_state),
            channel_token: header(headers, "x-goog-channel-token"),
            channel_expiration: header(headers, "x-goog-channel-expiration"),
            calendar_id: calendar_id_from_resource_uri(resource_uri),
            payload_kind: payload_kind(payload)
          }

        {:ok, Data.compact(signal)}

      missing ->
        {:error,
         Error.provider("Google Calendar channel notification headers are invalid",
           provider: :google,
           reason: :invalid_calendar_channel_headers,
           details: %{missing_headers: missing}
         )}
    end
  end

  defp missing_required_headers(headers) do
    @required_headers
    |> Map.values()
    |> Enum.filter(fn name -> blank?(header(headers, name)) end)
  end

  defp header(headers, name) when is_map(headers) do
    headers
    |> Enum.find_value(fn {key, value} ->
      if normalize_header_name(key) == name, do: header_value(value)
    end)
    |> trim()
  end

  defp header(headers, name) when is_list(headers) do
    Enum.find_value(headers, fn
      {key, value} ->
        if normalize_header_name(key) == name, do: header_value(value)

      _other ->
        nil
    end)
    |> trim()
  end

  defp header(_headers, _name), do: nil

  defp normalize_header_name(name) do
    name
    |> to_string()
    |> String.downcase()
  end

  defp header_value([value | _rest]), do: value
  defp header_value(value), do: value

  defp trim(value) when is_binary(value), do: String.trim(value)
  defp trim(value), do: value

  defp calendar_id_from_resource_uri(uri) when is_binary(uri) do
    case Regex.run(~r{/calendars/([^/?#]+)/(?:events|acl)}, uri) do
      [_match, calendar_id] -> URI.decode(calendar_id)
      _no_match -> nil
    end
  end

  defp calendar_id_from_resource_uri(_uri), do: nil

  defp resource_type(uri) when is_binary(uri) do
    cond do
      String.contains?(uri, "/events") -> "event"
      String.contains?(uri, "/calendarList") -> "calendar_list"
      String.contains?(uri, "/acl") -> "acl"
      String.contains?(uri, "/settings") -> "setting"
      true -> nil
    end
  end

  defp resource_type(_uri), do: nil

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
end
