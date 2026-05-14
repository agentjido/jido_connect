defmodule Jido.Connect.Google.Contacts.Handlers.Actions.SearchOtherContacts do
  @moduledoc false

  alias Jido.Connect.Google.Contacts.Handlers.Actions.Helpers

  @reason :invalid_contacts_other_request

  def run(input, %{credentials: credentials}) do
    input =
      input
      |> Map.put_new(:page_size, 10)
      |> Helpers.normalize_strings([:query])

    with :ok <- Helpers.require_string(input, :query, @reason),
         {:ok, client} <- Helpers.fetch_client(credentials),
         {:ok, result} <- client.search_other_contacts(input, Map.get(credentials, :access_token)) do
      {:ok, Helpers.people_result(result)}
    end
  end
end
