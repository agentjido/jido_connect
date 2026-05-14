defmodule Jido.Connect.Google.Contacts.Handlers.Actions.CopyOtherContact do
  @moduledoc false

  alias Jido.Connect.Google.Contacts.Handlers.Actions.Helpers

  @reason :invalid_contacts_other_request

  def run(input, %{credentials: credentials}) do
    input = Helpers.normalize_strings(input, [:resource_name])

    with :ok <- Helpers.require_present(input, :resource_name, @reason),
         {:ok, client} <- Helpers.fetch_client(credentials),
         {:ok, person} <- client.copy_other_contact(input, Map.get(credentials, :access_token)) do
      {:ok, %{person: Helpers.public_map(person)}}
    end
  end
end
