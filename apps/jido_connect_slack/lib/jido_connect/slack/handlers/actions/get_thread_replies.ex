defmodule Jido.Connect.Slack.Handlers.Actions.GetThreadReplies do
  @moduledoc false

  alias Jido.Connect.Data
  alias Jido.Connect.Slack.Handlers.ClientResolver

  def run(input, %{credentials: credentials} = context) do
    with {:ok, client} <- ClientResolver.fetch(context, credentials),
         {:ok, result} <-
           client.get_thread_replies(
             Map.take(input, [:channel, :ts, :limit, :cursor, :oldest, :latest, :inclusive]),
             Map.get(credentials, :access_token)
           ) do
      messages = Enum.map(result.messages, &normalize_message/1)

      {:ok,
       %{
         channel: Data.get(result, :channel, Data.get(input, :channel)),
         thread_ts: Data.get(result, :thread_ts, Data.get(input, :ts)),
         messages: messages,
         reply_count: reply_count(messages),
         latest_reply: latest_reply(messages),
         next_cursor: Data.get(result, :next_cursor, ""),
         has_more: Data.get(result, :has_more, false)
       }
       |> Data.compact()}
    end
  end

  defp normalize_message(message) when is_map(message) do
    %{
      type: Data.get(message, "type"),
      subtype: Data.get(message, "subtype"),
      user: Data.get(message, "user"),
      username: Data.get(message, "username"),
      bot_id: Data.get(message, "bot_id"),
      app_id: Data.get(message, "app_id"),
      text: Data.get(message, "text"),
      ts: Data.get(message, "ts"),
      thread_ts: Data.get(message, "thread_ts"),
      parent_user_id: Data.get(message, "parent_user_id"),
      reply_count: Data.get(message, "reply_count"),
      reply_users_count: Data.get(message, "reply_users_count"),
      latest_reply: Data.get(message, "latest_reply"),
      blocks: Data.get(message, "blocks"),
      files: Data.get(message, "files"),
      attachments: Data.get(message, "attachments"),
      reactions: Data.get(message, "reactions")
    }
    |> Data.compact()
  end

  defp reply_count([root | replies]), do: Data.get(root, :reply_count) || length(replies)
  defp reply_count([]), do: 0

  defp latest_reply([root | _messages] = messages) do
    Data.get(root, :latest_reply) ||
      messages
      |> Enum.map(&Data.get(&1, :ts))
      |> Enum.reject(&is_nil/1)
      |> List.last()
  end

  defp latest_reply([]), do: nil
end
