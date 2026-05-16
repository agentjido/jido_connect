defmodule Jido.Connect.Salesforce.Handlers.Actions.GetContact do
  @moduledoc false

  alias Jido.Connect.Salesforce.Handlers.Actions.ResourceHelpers

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- ResourceHelpers.fetch_client(credentials),
         credentials <- build_credentials(credentials),
         {:ok, contact} <- client.get_contact(input, credentials) do
      {:ok, %{contact: ResourceHelpers.public_map(contact)}}
    end
  end

  defp build_credentials(credentials) do
    Map.put(credentials, :instance_url, ResourceHelpers.instance_url(credentials))
  end
end
