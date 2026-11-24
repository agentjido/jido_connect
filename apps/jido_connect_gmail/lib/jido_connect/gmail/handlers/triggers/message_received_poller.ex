defmodule Jido.Connect.Gmail.Handlers.Triggers.MessageReceivedPoller do
  @moduledoc false

  alias Jido.Connect.Gmail.Handlers.Triggers.HistoryPoller

  def poll(config, context) do
    config
    |> Map.put_new(:page_size, 100)
    |> Map.put_new(:label_id, "INBOX")
    |> HistoryPoller.poll(context,
      history_types: ["messageAdded"],
      signals: &history_signals/1,
      dedupe: [:message_id]
    )
  end

  defp history_signals(history_record) do
    history_id = Map.get(history_record, :history_id)

    history_record
    |> Map.get(:messages_added, [])
    |> Enum.map(&message_signal(&1, history_id))
  end

  defp message_signal(message, history_id) do
    public_message = public_map(message)

    %{
      message_id: Map.get(message, :message_id),
      thread_id: Map.get(message, :thread_id),
      history_id: Map.get(message, :history_id) || history_id,
      label_ids: Map.get(message, :label_ids, []),
      snippet: Map.get(message, :snippet),
      internal_date: Map.get(message, :internal_date),
      size_estimate: Map.get(message, :size_estimate),
      headers: Map.get(message, :headers, []),
      message: public_message
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp public_map(struct) when is_struct(struct), do: struct |> Map.from_struct() |> public_map()
  defp public_map(map) when is_map(map), do: map
  defp public_map(value), do: value
end
