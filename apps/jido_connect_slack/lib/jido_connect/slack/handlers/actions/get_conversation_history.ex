defmodule Jido.Connect.Slack.Handlers.Actions.GetConversationHistory do
  @moduledoc false

  alias Jido.Connect.Slack.Handlers.ClientResolver
  alias Jido.Connect.Slack.Message

  @params [:channel, :conversation_type, :cursor, :oldest, :latest, :inclusive, :limit]

  # Messages leave as plain maps with every `Message` field, so the action
  # output stays JSON-encodable and no field is compacted away.
  def run(input, %{credentials: credentials} = context) do
    with {:ok, client} <- ClientResolver.fetch(context, credentials),
         {:ok, page} <-
           client.get_conversation_history(
             Map.take(input, @params),
             Map.get(credentials, :access_token)
           ) do
      {:ok, %{page | messages: Enum.map(page.messages, &message_map/1)}}
    end
  end

  defp message_map(%Message{} = message), do: Map.from_struct(message)
  defp message_map(message) when is_map(message), do: message
end
