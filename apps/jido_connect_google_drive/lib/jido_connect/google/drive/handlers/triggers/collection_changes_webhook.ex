defmodule Jido.Connect.Google.Drive.Handlers.Triggers.CollectionChangesWebhook do
  @moduledoc false

  alias Jido.Connect.Google.Drive.Webhook

  def normalize_signal(delivery) do
    with {:ok, signal} <- Webhook.normalize_signal(delivery) do
      {:ok, collection_signal(signal)}
    end
  end

  def normalize_channel_notification(headers, payload \\ nil) do
    with {:ok, signal} <- Webhook.normalize_channel_notification(headers, payload) do
      {:ok, collection_signal(signal)}
    end
  end

  defp collection_signal(signal) do
    %{
      collection_changed?: Map.get(signal, :resource_changed, false),
      channel_id: Map.get(signal, :channel_id),
      resource_id: Map.get(signal, :resource_id),
      message_number: Map.get(signal, :message_number),
      resource_state: Map.get(signal, :resource_state),
      delivery: Map.get(signal, :delivery)
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end
end
