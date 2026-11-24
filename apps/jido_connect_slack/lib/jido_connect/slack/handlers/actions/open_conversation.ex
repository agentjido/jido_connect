defmodule Jido.Connect.Slack.Handlers.Actions.OpenConversation do
  @moduledoc false

  alias Jido.Connect.Data
  alias Jido.Connect.Slack.Handlers.ClientResolver

  def run(input, %{credentials: credentials} = context) do
    with {:ok, client} <- ClientResolver.fetch(context, credentials),
         {:ok, result} <-
           client.open_conversation(
             Map.take(input, [:users, :channel, :return_im, :prevent_creation]),
             Map.get(credentials, :access_token)
           ) do
      conversation = Data.get(result, :conversation, %{})

      {:ok,
       %{
         channel: Data.get(result, :channel, Data.get(conversation, :id)),
         conversation: conversation
       }}
    end
  end
end
