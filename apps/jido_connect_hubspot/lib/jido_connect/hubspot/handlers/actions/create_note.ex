defmodule Jido.Connect.HubSpot.Handlers.Actions.CreateNote do
  @moduledoc false

  alias Jido.Connect.HubSpot.Handlers.Actions.ResourceHelpers

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- ResourceHelpers.fetch_client(credentials),
         token <- ResourceHelpers.credential_token(credentials),
         {:ok, note} <- client.create_note(input, token) do
      {:ok, %{note: ResourceHelpers.public_map(note)}}
    end
  end
end
