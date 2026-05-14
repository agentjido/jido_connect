defmodule Jido.Connect.Gmail.Client.Response do
  @moduledoc "Gmail response handling."

  alias Jido.Connect.Data
  alias Jido.Connect.Gmail.{Client.Transport, Normalizer}

  def handle_profile_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    normalize_one(body, &Normalizer.profile/1, "Gmail profile response was invalid")
  end

  def handle_profile_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Gmail profile response was invalid", body)
  end

  def handle_profile_response(response), do: Transport.handle_error_response(response)

  def handle_label_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    with {:ok, labels} <-
           normalize_items(
             body,
             "labels",
             &Normalizer.label/1,
             "Gmail label list response was invalid"
           ) do
      {:ok, %{labels: labels}}
    end
  end

  def handle_label_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Gmail label list response was invalid", body)
  end

  def handle_label_list_response(response), do: Transport.handle_error_response(response)

  def handle_draft_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    with {:ok, drafts} <-
           normalize_items(
             body,
             "drafts",
             &Normalizer.draft/1,
             "Gmail draft list response was invalid"
           ) do
      {:ok,
       %{
         drafts: drafts,
         next_page_token: Data.get(body, "nextPageToken"),
         result_size_estimate: Data.get(body, "resultSizeEstimate")
       }
       |> Data.compact()}
    end
  end

  def handle_draft_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Gmail draft list response was invalid", body)
  end

  def handle_draft_list_response(response), do: Transport.handle_error_response(response)

  def handle_label_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    normalize_one(body, &Normalizer.label/1, "Gmail label response was invalid")
  end

  def handle_label_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Gmail label response was invalid", body)
  end

  def handle_label_response(response), do: Transport.handle_error_response(response)

  def handle_message_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    with {:ok, messages} <-
           normalize_items(
             body,
             "messages",
             &Normalizer.message/1,
             "Gmail message list response was invalid"
           ) do
      {:ok,
       %{
         messages: messages,
         next_page_token: Data.get(body, "nextPageToken"),
         result_size_estimate: Data.get(body, "resultSizeEstimate")
       }
       |> Data.compact()}
    end
  end

  def handle_message_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Gmail message list response was invalid", body)
  end

  def handle_message_list_response(response), do: Transport.handle_error_response(response)

  def handle_message_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    normalize_one(body, &Normalizer.message/1, "Gmail message response was invalid")
  end

  def handle_message_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Gmail message response was invalid", body)
  end

  def handle_message_response(response), do: Transport.handle_error_response(response)

  def handle_thread_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    with {:ok, threads} <-
           normalize_items(
             body,
             "threads",
             &Normalizer.thread/1,
             "Gmail thread list response was invalid"
           ) do
      {:ok,
       %{
         threads: threads,
         next_page_token: Data.get(body, "nextPageToken"),
         result_size_estimate: Data.get(body, "resultSizeEstimate")
       }
       |> Data.compact()}
    end
  end

  def handle_thread_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Gmail thread list response was invalid", body)
  end

  def handle_thread_list_response(response), do: Transport.handle_error_response(response)

  def handle_thread_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    normalize_one(body, &Normalizer.thread/1, "Gmail thread response was invalid")
  end

  def handle_thread_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Gmail thread response was invalid", body)
  end

  def handle_thread_response(response), do: Transport.handle_error_response(response)

  def handle_history_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    with {:ok, history} <-
           normalize_items(
             body,
             "history",
             &history_record/1,
             "Gmail history list response was invalid"
           ) do
      {:ok,
       %{
         history: history,
         next_page_token: Data.get(body, "nextPageToken"),
         history_id: normalize_string(Data.get(body, "historyId"))
       }
       |> Data.compact()}
    end
  end

  def handle_history_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Gmail history list response was invalid", body)
  end

  def handle_history_list_response(response), do: Transport.handle_error_response(response)

  def handle_watch_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    normalize_one(body, &Normalizer.watch/1, "Gmail watch response was invalid")
  end

  def handle_watch_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Gmail watch response was invalid", body)
  end

  def handle_watch_response(response), do: Transport.handle_error_response(response)

  def handle_stop_watch_response({:ok, %{status: status}}) when status in 200..299 do
    {:ok, %{stopped?: true}}
  end

  def handle_stop_watch_response(response), do: Transport.handle_error_response(response)

  def handle_empty_response({:ok, %{status: status}}, result) when status in 200..299 do
    {:ok, result}
  end

  def handle_empty_response(response, _result), do: Transport.handle_error_response(response)

  def handle_attachment_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    normalize_one(body, &Normalizer.attachment/1, "Gmail attachment response was invalid")
  end

  def handle_attachment_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Gmail attachment response was invalid", body)
  end

  def handle_attachment_response(response), do: Transport.handle_error_response(response)

  def handle_draft_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    normalize_one(body, &Normalizer.draft/1, "Gmail draft response was invalid")
  end

  def handle_draft_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Gmail draft response was invalid", body)
  end

  def handle_draft_response(response), do: Transport.handle_error_response(response)

  defp normalize_one(body, normalizer, message) do
    case normalizer.(body) do
      {:ok, item} -> {:ok, item}
      {:error, _error} -> Transport.invalid_success_response(message, body)
    end
  end

  defp normalize_items(body, key, normalizer, message) do
    case Data.get(body, key, []) do
      items when is_list(items) ->
        items
        |> Enum.reduce_while({:ok, []}, fn payload, {:ok, acc} ->
          case normalizer.(payload) do
            {:ok, item} -> {:cont, {:ok, [item | acc]}}
            {:error, _error} -> {:halt, Transport.invalid_success_response(message, body)}
          end
        end)
        |> case do
          {:ok, items} -> {:ok, Enum.reverse(items)}
          {:error, error} -> {:error, error}
        end

      _invalid ->
        Transport.invalid_success_response(message, body)
    end
  end

  defp history_record(payload) when is_map(payload) do
    with {:ok, messages} <-
           normalize_items(
             payload,
             "messages",
             &Normalizer.message/1,
             "Gmail history list response was invalid"
           ),
         {:ok, messages_added} <-
           normalize_items(
             payload,
             "messagesAdded",
             &message_added/1,
             "Gmail history list response was invalid"
           ),
         {:ok, messages_deleted} <-
           normalize_items(
             payload,
             "messagesDeleted",
             &message_added/1,
             "Gmail history list response was invalid"
           ),
         {:ok, labels_added} <-
           normalize_items(
             payload,
             "labelsAdded",
             &label_change/1,
             "Gmail history list response was invalid"
           ),
         {:ok, labels_removed} <-
           normalize_items(
             payload,
             "labelsRemoved",
             &label_change/1,
             "Gmail history list response was invalid"
           ) do
      {:ok,
       %{
         history_id: normalize_string(Data.get(payload, "id")),
         messages: messages,
         messages_added: messages_added,
         messages_deleted: messages_deleted,
         labels_added: labels_added,
         labels_removed: labels_removed
       }
       |> compact_history_record()}
    end
  end

  defp history_record(_payload), do: {:error, :invalid_history_record}

  defp message_added(payload) when is_map(payload) do
    payload
    |> Data.get("message", %{})
    |> Normalizer.message()
  end

  defp message_added(_payload), do: {:error, :invalid_message_added}

  defp label_change(payload) when is_map(payload) do
    with {:ok, message} <- payload |> Data.get("message", %{}) |> Normalizer.message(),
         {:ok, label_ids} <- normalize_label_ids(Data.get(payload, "labelIds", [])) do
      {:ok,
       %{
         message: message,
         label_ids: label_ids
       }
       |> Data.compact()}
    end
  end

  defp label_change(_payload), do: {:error, :invalid_label_change}

  defp normalize_label_ids(label_ids) when is_list(label_ids) do
    if Enum.all?(label_ids, &is_binary/1) do
      {:ok, label_ids}
    else
      {:error, :invalid_label_ids}
    end
  end

  defp normalize_label_ids(_label_ids), do: {:error, :invalid_label_ids}

  defp compact_history_record(map) do
    map
    |> Enum.reject(fn {_key, value} -> is_nil(value) or value == [] end)
    |> Map.new()
  end

  defp normalize_string(nil), do: nil
  defp normalize_string(value) when is_binary(value), do: value
  defp normalize_string(value), do: to_string(value)
end
