defmodule Jido.Connect.Gmail.Webhook do
  @moduledoc """
  Pure helpers for Gmail Cloud Pub/Sub webhook payload normalization.

  Gmail push notifications are delivered through Google Cloud Pub/Sub. The
  connector declares OIDC verification requirements in trigger metadata, while
  these helpers normalize the provider payload after the host has accepted the
  request.
  """

  alias Jido.Connect.{Data, Error, WebhookDelivery}

  @doc "Normalizes a Gmail Pub/Sub push payload into the mailbox changed signal shape."
  @spec normalize_pubsub_push(map()) :: {:ok, map()} | {:error, Error.ProviderError.t()}
  def normalize_pubsub_push(%{"message" => message} = payload) when is_map(message) do
    with {:ok, data} <- decode_message_data(Data.get(message, "data")),
         :ok <- require_history_id(data) do
      {:ok,
       Data.compact(%{
         email_address: Data.get(data, "emailAddress"),
         history_id: normalize_string(Data.get(data, "historyId")),
         message_id: Data.get(message, "messageId") || Data.get(message, "message_id"),
         publish_time: Data.get(message, "publishTime") || Data.get(message, "publish_time"),
         subscription: Data.get(payload, "subscription")
       })}
    end
  end

  def normalize_pubsub_push(_payload) do
    {:error,
     Error.provider("Gmail Pub/Sub push payload is invalid",
       provider: :google,
       reason: :invalid_pubsub_payload
     )}
  end

  @doc "Normalizes a webhook delivery into a mailbox changed signal."
  @spec normalize_signal(WebhookDelivery.t()) :: {:ok, map()} | {:error, Error.ProviderError.t()}
  def normalize_signal(%WebhookDelivery{payload: payload} = delivery) do
    with {:ok, signal} <- normalize_pubsub_push(payload) do
      {:ok, Map.put(signal, :delivery, delivery_metadata(delivery))}
    end
  end

  def normalize_signal(payload) when is_map(payload), do: normalize_pubsub_push(payload)

  defp decode_message_data(data) when is_binary(data) do
    with {:ok, decoded} <- decode_base64(data),
         {:ok, %{} = payload} <- Jason.decode(decoded) do
      {:ok, payload}
    else
      {:ok, _other} ->
        invalid_data()

      :error ->
        invalid_data()

      {:error, _error} ->
        invalid_data()
    end
  end

  defp decode_message_data(_data), do: invalid_data()

  defp decode_base64(data) do
    Enum.find_value(
      [
        fn -> Base.url_decode64(data, padding: false) end,
        fn -> Base.url_decode64(data, padding: true) end,
        fn -> Base.decode64(data, padding: false) end,
        fn -> Base.decode64(data, padding: true) end
      ],
      fn decoder ->
        case decoder.() do
          {:ok, decoded} -> {:ok, decoded}
          :error -> nil
        end
      end
    ) || :error
  end

  defp require_history_id(data) do
    case Data.get(data, "historyId") do
      value when value in [nil, ""] -> invalid_data()
      _value -> :ok
    end
  end

  defp invalid_data do
    {:error,
     Error.provider("Gmail Pub/Sub message data is invalid",
       provider: :google,
       reason: :invalid_pubsub_data
     )}
  end

  defp delivery_metadata(%WebhookDelivery{} = delivery) do
    Data.compact(%{
      provider: delivery.provider,
      event: delivery.event,
      id: delivery.delivery_id,
      duplicate?: delivery.duplicate?,
      received_at: delivery.received_at
    })
  end

  defp normalize_string(nil), do: nil
  defp normalize_string(value) when is_binary(value), do: value
  defp normalize_string(value), do: to_string(value)
end
