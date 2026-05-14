defmodule Jido.Connect.Google.Contacts.Handlers.Actions.SearchDirectoryPeople do
  @moduledoc false

  alias Jido.Connect.Google.Contacts.Handlers.Actions.Helpers

  @reason :invalid_contacts_directory_request

  def run(input, %{credentials: credentials}) do
    input =
      input
      |> Map.put_new(:page_size, 10)
      |> Helpers.normalize_strings([:query])

    with :ok <- Helpers.require_present(input, :query, @reason),
         {:ok, client} <- Helpers.fetch_client(credentials),
         {:ok, result} <-
           client.search_directory_people(input, Map.get(credentials, :access_token)) do
      {:ok, Helpers.people_result(result)}
    end
  end
end
