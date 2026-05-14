defmodule Jido.Connect.Google.Contacts.Handlers.Actions.ListDirectoryPeople do
  @moduledoc false

  alias Jido.Connect.Google.Contacts.Handlers.Actions.Helpers

  def run(input, %{credentials: credentials}) do
    input =
      input
      |> Map.put_new(:page_size, 100)
      |> Map.put_new(:request_sync_token, false)

    with {:ok, client} <- Helpers.fetch_client(credentials),
         {:ok, result} <- client.list_directory_people(input, Map.get(credentials, :access_token)) do
      {:ok, Helpers.people_result(result)}
    end
  end
end
