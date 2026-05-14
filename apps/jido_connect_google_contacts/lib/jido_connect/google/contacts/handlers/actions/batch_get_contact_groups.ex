defmodule Jido.Connect.Google.Contacts.Handlers.Actions.BatchGetContactGroups do
  @moduledoc false

  alias Jido.Connect.Google.Contacts.Handlers.Actions.Helpers

  @reason :invalid_contacts_group_request

  def run(input, %{credentials: credentials}) do
    with :ok <- Helpers.validate_resource_names(input, @reason),
         {:ok, client} <- Helpers.fetch_client(credentials),
         {:ok, result} <-
           client.batch_get_contact_groups(input, Map.get(credentials, :access_token)) do
      {:ok,
       %{
         groups: Helpers.public_map(Map.get(result, :groups, [])),
         responses: Helpers.public_map(Map.get(result, :responses, []))
       }}
    end
  end
end
