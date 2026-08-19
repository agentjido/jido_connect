defmodule Jido.Connect.Slack.Handlers.Actions.ListUnreadMessages do
  @moduledoc false

  alias Jido.Connect.{Data, Error}
  alias Jido.Connect.Slack.Handlers.ClientResolver

  def run(input, %{credentials: credentials} = context) do
    with :ok <- validate_limit(Data.get(input, :limit, 20)),
         {:ok, client} <- ClientResolver.fetch(context, credentials),
         {:ok, result} <-
           client.list_unread_messages(
             Map.take(input, [:channel, :conversation_type, :limit]),
             Map.get(credentials, :access_token)
           ) do
      {:ok,
       %{
         messages: Data.get(result, :messages, []),
         conversations: Data.get(result, :conversations, []),
         count: Data.get(result, :count, 0),
         truncated: Data.get(result, :truncated, false),
         coverage: Data.get(result, :coverage, %{})
       }}
    end
  end

  defp validate_limit(limit) when is_integer(limit) and limit in 1..100, do: :ok

  defp validate_limit(_limit) do
    {:error,
     Error.validation("Slack unread-message limit must be from 1 through 100",
       reason: :invalid_limit
     )}
  end
end
