defmodule Jido.Connect.Google.Contacts.Handlers.Actions.BatchUpdateContacts do
  @moduledoc false

  alias Jido.Connect.Google.Contacts.Handlers.Actions.Helpers

  @reason :invalid_contacts_batch_request

  def run(input, %{credentials: credentials}) do
    with :ok <- Helpers.validate_contacts(input, @reason, resource_name?: true, etag?: true),
         {:ok, client} <- Helpers.fetch_client(credentials),
         {:ok, result} <- client.batch_update_contacts(input, Map.get(credentials, :access_token)) do
      {:ok, Helpers.people_result(result)}
    end
  end
end
