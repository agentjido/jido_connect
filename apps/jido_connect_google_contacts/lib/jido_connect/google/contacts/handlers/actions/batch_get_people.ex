defmodule Jido.Connect.Google.Contacts.Handlers.Actions.BatchGetPeople do
  @moduledoc false

  alias Jido.Connect.Google.Contacts.Handlers.Actions.Helpers

  @reason :invalid_contacts_batch_request

  def run(input, %{credentials: credentials}) do
    with :ok <- Helpers.validate_resource_names(input, @reason),
         {:ok, client} <- Helpers.fetch_client(credentials),
         {:ok, result} <- client.batch_get_people(input, Map.get(credentials, :access_token)) do
      {:ok, Helpers.people_result(result)}
    end
  end
end
