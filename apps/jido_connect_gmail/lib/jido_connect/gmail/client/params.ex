defmodule Jido.Connect.Gmail.Client.Params do
  @moduledoc "Gmail request parameter helpers."

  def message_list_params(params) when is_map(params) do
    []
    |> maybe_put(:q, Map.get(params, :query))
    |> put_repeated(:labelIds, Map.get(params, :label_ids, []))
    |> maybe_put(:maxResults, Map.get(params, :page_size, 25))
    |> maybe_put(:pageToken, Map.get(params, :page_token))
    |> maybe_put(:includeSpamTrash, Map.get(params, :include_spam_trash))
  end

  def thread_list_params(params) when is_map(params), do: message_list_params(params)

  def draft_list_params(params) when is_map(params) do
    []
    |> maybe_put(:q, Map.get(params, :query))
    |> maybe_put(:maxResults, Map.get(params, :page_size, 25))
    |> maybe_put(:pageToken, Map.get(params, :page_token))
    |> maybe_put(:includeSpamTrash, Map.get(params, :include_spam_trash))
  end

  def metadata_get_params(params) when is_map(params) do
    []
    |> maybe_put(:format, "metadata")
    |> put_repeated(:metadataHeaders, Map.get(params, :metadata_headers, []))
  end

  def history_list_params(params) when is_map(params) do
    []
    |> maybe_put(:startHistoryId, Map.fetch!(params, :start_history_id))
    |> maybe_put(:labelId, Map.get(params, :label_id))
    |> maybe_put(:maxResults, Map.get(params, :page_size, 100))
    |> maybe_put(:pageToken, Map.get(params, :page_token))
    |> put_repeated(:historyTypes, Map.get(params, :history_types, []))
  end

  def watch_body(params) when is_map(params) do
    %{
      topicName: Map.fetch!(params, :topic_name),
      labelIds: Map.get(params, :label_ids, []),
      labelFilterBehavior: Map.get(params, :label_filter_behavior)
    }
    |> compact()
  end

  def send_message_body(params) when is_map(params) do
    %{
      raw: Map.fetch!(params, :raw),
      threadId: Map.get(params, :thread_id)
    }
    |> compact()
  end

  def create_draft_body(params) when is_map(params) do
    %{message: send_message_body(params)}
  end

  def update_draft_body(params) when is_map(params), do: create_draft_body(params)

  def send_draft_body(params) when is_map(params) do
    %{id: Map.fetch!(params, :draft_id)}
  end

  def label_body(params) when is_map(params) do
    %{
      name: Map.get(params, :name),
      messageListVisibility: Map.get(params, :message_list_visibility),
      labelListVisibility: Map.get(params, :label_list_visibility),
      color: Map.get(params, :color)
    }
    |> compact()
  end

  def modify_labels_body(params) when is_map(params) do
    %{
      addLabelIds: Map.get(params, :add_label_ids, []),
      removeLabelIds: Map.get(params, :remove_label_ids, [])
    }
    |> compact()
  end

  def batch_modify_messages_body(params) when is_map(params) do
    params
    |> modify_labels_body()
    |> Map.put(:ids, Map.fetch!(params, :message_ids))
  end

  def batch_delete_messages_body(params) when is_map(params) do
    %{ids: Map.fetch!(params, :message_ids)}
  end

  defp put_repeated(params, _key, nil), do: params
  defp put_repeated(params, _key, []), do: params

  defp put_repeated(params, key, values) when is_list(values),
    do: params ++ Enum.map(values, &{key, &1})

  defp put_repeated(params, key, value), do: Keyword.put(params, key, value)

  defp maybe_put(params, _key, nil), do: params
  defp maybe_put(params, _key, ""), do: params
  defp maybe_put(params, key, value), do: Keyword.put(params, key, value)

  defp compact(map) do
    map
    |> Enum.reject(fn {_key, value} -> is_nil(value) or value == "" end)
    |> Map.new()
  end
end
