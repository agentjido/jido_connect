defmodule Jido.Connect.Salesforce.Handlers.Actions.ListContacts do
  @moduledoc false

  alias Jido.Connect.Salesforce.Handlers.Actions.ResourceHelpers

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- ResourceHelpers.fetch_client(credentials),
         credentials <- build_credentials(credentials),
         {:ok, %{items: contacts, pagination: pagination}} <-
           client.list_contacts(input, credentials) do
      {:ok,
       %{
         contacts: ResourceHelpers.public_map(contacts),
         pagination: ResourceHelpers.public_map(pagination)
       }}
    end
  end

  defp build_credentials(credentials) do
    Map.put(credentials, :instance_url, ResourceHelpers.instance_url(credentials))
  end
end
