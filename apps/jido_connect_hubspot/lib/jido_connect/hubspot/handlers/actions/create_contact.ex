defmodule Jido.Connect.HubSpot.Handlers.Actions.CreateContact do
  @moduledoc false

  alias Jido.Connect.HubSpot.Handlers.Actions.ResourceHelpers

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- ResourceHelpers.fetch_client(credentials),
         token <- ResourceHelpers.credential_token(credentials),
         {:ok, contact} <- client.create_contact(input, token) do
      {:ok, %{contact: ResourceHelpers.public_map(contact)}}
    end
  end
end
