defmodule Jido.Connect.Google.Contacts.Handlers.Actions.ModifyContactGroupMembers do
  @moduledoc false

  alias Jido.Connect.Google.Contacts.Handlers.Actions.Helpers

  @reason :invalid_contacts_group_request

  def run(input, %{credentials: credentials}) do
    input = Helpers.normalize_strings(input, [:resource_name])

    with :ok <- Helpers.require_present(input, :resource_name, @reason),
         :ok <-
           Helpers.validate_any_resource_names(
             input,
             [:resource_names_to_add, :resource_names_to_remove],
             @reason
           ),
         {:ok, client} <- Helpers.fetch_client(credentials),
         {:ok, result} <-
           client.modify_contact_group_members(input, Map.get(credentials, :access_token)) do
      {:ok, %{result: Helpers.public_map(result)}}
    end
  end
end
