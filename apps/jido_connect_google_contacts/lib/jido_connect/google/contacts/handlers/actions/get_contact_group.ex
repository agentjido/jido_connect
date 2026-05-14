defmodule Jido.Connect.Google.Contacts.Handlers.Actions.GetContactGroup do
  @moduledoc false

  alias Jido.Connect.Google.Contacts.Handlers.Actions.Helpers

  @reason :invalid_contacts_group_request

  def run(input, %{credentials: credentials}) do
    input = Helpers.normalize_strings(input, [:resource_name])

    with :ok <- Helpers.require_present(input, :resource_name, @reason),
         {:ok, client} <- Helpers.fetch_client(credentials),
         {:ok, group} <- client.get_contact_group(input, Map.get(credentials, :access_token)) do
      {:ok, %{group: Helpers.public_map(group)}}
    end
  end
end
