defmodule Jido.Connect.Google.Contacts.Handlers.Actions.BatchDeleteContacts do
  @moduledoc false

  alias Jido.Connect.Google.Contacts.Handlers.Actions.Helpers

  @reason :invalid_contacts_batch_request

  def run(input, %{credentials: credentials}) do
    with :ok <- Helpers.validate_resource_names(input, @reason),
         {:ok, client} <- Helpers.fetch_client(credentials),
         {:ok, result} <- client.batch_delete_contacts(input, Map.get(credentials, :access_token)) do
      {:ok, %{result: Helpers.public_map(result)}}
    end
  end
end
