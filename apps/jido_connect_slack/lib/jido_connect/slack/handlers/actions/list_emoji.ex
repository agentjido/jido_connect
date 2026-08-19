defmodule Jido.Connect.Slack.Handlers.Actions.ListEmoji do
  @moduledoc false

  alias Jido.Connect.Data
  alias Jido.Connect.Slack.Handlers.ClientResolver

  def run(_input, %{credentials: credentials} = context) do
    with {:ok, client} <- ClientResolver.fetch(context, credentials),
         {:ok, result} <- client.list_emoji(Map.get(credentials, :access_token)) do
      emoji = Data.get(result, :emoji, [])
      {:ok, %{emoji: emoji, count: length(emoji)}}
    end
  end
end
