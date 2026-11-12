defmodule Jido.Connect.Gmail.Handlers.Actions.GetMessageContent do
  @moduledoc false

  alias Jido.Connect.Gmail.Handlers.Actions.{Content, Mutation}

  def run(input, %{credentials: credentials}) do
    access_token = Map.get(credentials, :access_token)

    with {:ok, %{message_id: message_id}} <- Mutation.normalize_required_id(input, :message_id),
         {:ok, client} <- Mutation.fetch_client(credentials),
         {:ok, resource} <- client.get_message_content(%{message_id: message_id}, access_token),
         {:ok, message} <- Content.message(resource, client, access_token) do
      {:ok, %{message: Mutation.public_map(message)}}
    end
  end
end
