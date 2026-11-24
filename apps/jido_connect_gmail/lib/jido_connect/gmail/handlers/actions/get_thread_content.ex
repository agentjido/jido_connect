defmodule Jido.Connect.Gmail.Handlers.Actions.GetThreadContent do
  @moduledoc false

  alias Jido.Connect.Gmail.Handlers.Actions.{Content, Mutation}

  def run(input, %{credentials: credentials}) do
    access_token = Map.get(credentials, :access_token)

    with {:ok, %{thread_id: thread_id}} <- Mutation.normalize_required_id(input, :thread_id),
         {:ok, max_messages} <- Content.max_messages(input),
         {:ok, client} <- Mutation.fetch_client(credentials),
         {:ok, resource} <- client.get_thread_content(%{thread_id: thread_id}, access_token),
         {:ok, thread} <- Content.thread(resource, client, access_token, max_messages) do
      {:ok, %{thread: Mutation.public_map(thread)}}
    end
  end
end
