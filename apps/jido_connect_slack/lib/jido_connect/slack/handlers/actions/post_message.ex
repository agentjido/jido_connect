defmodule Jido.Connect.Slack.Handlers.Actions.PostMessage do
  @moduledoc false

  alias Jido.Connect.Slack.Handlers.ClientResolver

  def run(input, %{credentials: credentials} = context) do
    with {:ok, client} <- ClientResolver.fetch(context, credentials),
         {:ok, message} <-
           client.post_message(
             input
             |> Map.take([:channel, :text, :thread_ts, :reply_broadcast])
             |> Map.put_new(:reply_broadcast, false),
             Map.get(credentials, :access_token)
           ) do
      {:ok,
       %{
         channel: Map.fetch!(message, :channel),
         ts: Map.fetch!(message, :ts),
         message: Map.get(message, :message, %{})
       }}
    end
  end
end
