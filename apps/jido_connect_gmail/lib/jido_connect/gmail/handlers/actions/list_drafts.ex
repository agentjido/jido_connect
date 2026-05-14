defmodule Jido.Connect.Gmail.Handlers.Actions.ListDrafts do
  @moduledoc false

  alias Jido.Connect.Gmail.Handlers.Actions.Mutation

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- Mutation.fetch_client(credentials),
         {:ok, result} <-
           client.list_drafts(normalize_input(input), Map.get(credentials, :access_token)) do
      {:ok, Mutation.public_map(result)}
    end
  end

  defp normalize_input(input) do
    input
    |> Map.put_new(:page_size, 25)
    |> Map.put_new(:include_spam_trash, false)
  end
end
