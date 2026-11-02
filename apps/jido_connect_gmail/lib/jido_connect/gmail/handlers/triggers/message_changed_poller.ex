defmodule Jido.Connect.Gmail.Handlers.Triggers.MessageChangedPoller do
  @moduledoc false

  # One signal per message in `messagesDeleted`, `labelsAdded` and
  # `labelsRemoved` of a history record, in that order. `history_id` is the
  # record's ID, `changed_label_ids` the labels that the change added or
  # removed and `label_ids` the message's labels after it, as Gmail reports
  # them. A record without these arrays, such as one with `messages` or
  # `messagesAdded` only, yields no signal.

  alias Jido.Connect.Gmail.Handlers.Triggers.HistoryPoller

  def poll(config, context) do
    config
    |> Map.put_new(:page_size, 100)
    |> HistoryPoller.poll(context,
      history_types: ["messageDeleted", "labelAdded", "labelRemoved"],
      signals: &change_signals/1,
      dedupe: [:history_id, :message_id, :change_type]
    )
  end

  defp change_signals(record) do
    history_id = Map.get(record, :history_id)

    deleted =
      for message <- Map.get(record, :messages_deleted, []),
          do: signal("message_deleted", message, [], history_id)

    added =
      for change <- Map.get(record, :labels_added, []),
          do: signal("label_added", change.message, Map.get(change, :label_ids, []), history_id)

    removed =
      for change <- Map.get(record, :labels_removed, []),
          do: signal("label_removed", change.message, Map.get(change, :label_ids, []), history_id)

    deleted ++ added ++ removed
  end

  defp signal(change_type, message, changed_label_ids, history_id) do
    %{
      change_type: change_type,
      message_id: message.message_id,
      thread_id: message.thread_id,
      history_id: history_id,
      changed_label_ids: changed_label_ids,
      label_ids: message.label_ids
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end
end
