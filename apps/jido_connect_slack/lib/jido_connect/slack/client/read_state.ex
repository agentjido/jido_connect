defmodule Jido.Connect.Slack.Client.ReadState do
  @moduledoc "Slack conversation read-state and bounded unread-message API boundary."

  alias Jido.Connect.Data
  alias Jido.Connect.Slack.Client.{Response, Transport}

  @max_conversations 100
  @max_pages 5

  def mark_conversation_read(attrs, access_token)
      when is_map(attrs) and is_binary(access_token) do
    with {:ok, _response} <- post("/conversations.mark", attrs, access_token) do
      {:ok, %{channel: Data.get(attrs, :channel), ts: Data.get(attrs, :ts)}}
    end
  end

  def list_unread_messages(params, access_token)
      when is_map(params) and is_binary(access_token) do
    limit = Data.get(params, :limit, 20)

    with {:ok, conversations, list_truncated} <- conversations(params, access_token),
         {supported, unsupported} <- Enum.split_with(conversations, &has_read_state?/1),
         candidates <- Enum.filter(supported, &may_have_unread?/1),
         {:ok, messages, history_truncated} <- unread_messages(candidates, limit, access_token) do
      used_conversations =
        messages
        |> Enum.map(& &1.conversation)
        |> Enum.uniq_by(& &1.id)

      {:ok,
       %{
         messages: Enum.map(messages, &Map.delete(&1, :conversation)),
         conversations: used_conversations,
         count: length(messages),
         truncated: list_truncated or history_truncated,
         coverage: %{
           complete: unsupported == [] and not list_truncated and not history_truncated,
           inspected_conversation_count: length(conversations),
           supported_conversation_count: length(supported),
           unsupported_conversation_count: length(unsupported)
         }
       }}
    end
  end

  defp conversations(params, access_token) do
    case Data.get(params, :channel) do
      channel when is_binary(channel) and channel != "" ->
        with {:ok, response} <- get("/conversations.info", %{channel: channel}, access_token),
             conversation when is_map(conversation) <- Data.get(response, "channel"),
             true <- valid_conversation?(conversation) do
          {:ok, [conversation], false}
        else
          {:error, _error} = error ->
            error

          _other ->
            Transport.invalid_success_response("Slack conversation response was invalid", %{})
        end

      _channel ->
        list_conversations(access_token, nil, 1, [])
    end
  end

  defp list_conversations(access_token, cursor, page, collected) do
    remaining = @max_conversations - length(collected)

    params =
      %{
        types: "public_channel,private_channel,mpim,im",
        exclude_archived: true,
        limit: min(max(remaining, 1), 200)
      }
      |> maybe_put(:cursor, cursor)

    with {:ok, response} <- get("/users.conversations", params, access_token),
         channels when is_list(channels) <- Data.get(response, "channels"),
         true <- Enum.all?(channels, &valid_conversation?/1) do
      collected = Enum.take(collected ++ channels, @max_conversations)
      next_cursor = next_cursor(response)

      if is_nil(next_cursor) or page >= @max_pages or length(collected) >= @max_conversations do
        {:ok, collected, not is_nil(next_cursor)}
      else
        list_conversations(access_token, next_cursor, page + 1, collected)
      end
    else
      {:error, _error} = error ->
        error

      _other ->
        Transport.invalid_success_response("Slack conversation list response was invalid", %{})
    end
  end

  defp unread_messages(conversations, limit, access_token) do
    Enum.reduce_while(conversations, {:ok, [], false}, fn conversation,
                                                          {:ok, messages, truncated} ->
      remaining = limit - length(messages)

      if remaining <= 0 do
        {:halt, {:ok, messages, true}}
      else
        channel = Data.get(conversation, "id")

        params =
          %{channel: channel, inclusive: false, limit: min(remaining, 100)}
          |> maybe_oldest(Data.get(conversation, "last_read"))

        case get("/conversations.history", params, access_token) do
          {:ok, response} ->
            raw_messages = Data.get(response, "messages")

            if is_list(raw_messages) and Enum.all?(raw_messages, &valid_message?/1) do
              normalized = Enum.map(raw_messages, &normalize_message(&1, conversation))
              has_more = Data.get(response, "has_more", false) == true
              {:cont, {:ok, Enum.take(messages ++ normalized, limit), truncated or has_more}}
            else
              {:halt,
               Transport.invalid_success_response("Slack history response was invalid", response)}
            end

          {:error, _error} = error ->
            {:halt, error}
        end
      end
    end)
    |> case do
      {:ok, messages, truncated} ->
        {:ok, Enum.sort_by(messages, & &1.ts, :desc), truncated}

      {:error, _error} = error ->
        error
    end
  end

  defp normalize_message(message, conversation) do
    conversation = normalize_conversation(conversation)

    %{
      channel_id: conversation.id,
      channel_name: conversation.name,
      conversation_type: conversation.type,
      ts: Data.get(message, "ts"),
      thread_ts: Data.get(message, "thread_ts"),
      user_id: Data.get(message, "user"),
      text: Data.get(message, "text"),
      reply_count: Data.get(message, "reply_count"),
      reactions: Data.get(message, "reactions"),
      conversation: conversation
    }
    |> Data.compact()
  end

  defp normalize_conversation(conversation) do
    %{
      id: Data.get(conversation, "id"),
      name: Data.get(conversation, "name", Data.get(conversation, "id")),
      type: conversation_type(conversation),
      last_read: Data.get(conversation, "last_read"),
      unread_count: unread_count(conversation)
    }
    |> Data.compact()
  end

  defp conversation_type(conversation) do
    cond do
      Data.get(conversation, "is_im") == true -> "im"
      Data.get(conversation, "is_mpim") == true -> "mpim"
      Data.get(conversation, "is_private") == true -> "private_channel"
      true -> "public_channel"
    end
  end

  defp valid_conversation?(conversation) when is_map(conversation) do
    case Data.get(conversation, "id") do
      value when is_binary(value) and value != "" -> true
      _value -> false
    end
  end

  defp valid_conversation?(_conversation), do: false

  defp valid_message?(message) when is_map(message) do
    case Data.get(message, "ts") do
      value when is_binary(value) and value != "" -> true
      _value -> false
    end
  end

  defp valid_message?(_message), do: false

  defp has_read_state?(conversation) do
    is_binary(Data.get(conversation, "last_read")) or not is_nil(unread_count(conversation))
  end

  defp may_have_unread?(conversation) do
    count = unread_count(conversation)
    last_read = Data.get(conversation, "last_read")
    (is_integer(count) and count > 0) or (is_nil(count) and is_binary(last_read))
  end

  defp unread_count(conversation) do
    case Data.get(conversation, "unread_count_display", Data.get(conversation, "unread_count")) do
      value when is_integer(value) and value >= 0 -> value
      _value -> nil
    end
  end

  defp next_cursor(response) do
    case get_in(response, ["response_metadata", "next_cursor"]) do
      value when is_binary(value) and value != "" -> value
      _value -> nil
    end
  end

  defp maybe_oldest(params, "0000000000.000000"), do: params

  defp maybe_oldest(params, value) when is_binary(value) and value != "",
    do: Map.put(params, :oldest, value)

  defp maybe_oldest(params, _value), do: params
  defp maybe_put(params, _key, nil), do: params
  defp maybe_put(params, key, value), do: Map.put(params, key, value)

  defp get(path, params, access_token) do
    access_token
    |> Transport.request()
    |> Req.get(url: path, params: params)
    |> Response.handle_map_response()
  end

  defp post(path, body, access_token) do
    access_token
    |> Transport.request()
    |> Req.post(url: path, json: body)
    |> Response.handle_map_response()
  end
end
