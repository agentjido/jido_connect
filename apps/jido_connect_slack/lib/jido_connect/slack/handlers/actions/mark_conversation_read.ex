defmodule Jido.Connect.Slack.Handlers.Actions.MarkConversationRead do
  @moduledoc false

  alias Jido.Connect.Data
  alias Jido.Connect.Slack.Handlers.ClientResolver

  def run(input, %{credentials: credentials} = context) do
    with {:ok, client} <- ClientResolver.fetch(context, credentials),
         {:ok, result} <-
           client.mark_conversation_read(
             Map.take(input, [:channel, :ts]),
             Map.get(credentials, :access_token)
           ) do
      {:ok,
       %{
         channel: Data.get(result, :channel, Data.get(input, :channel)),
         ts: Data.get(result, :ts, Data.get(input, :ts)),
         marked: true
       }}
    end
  end
end
