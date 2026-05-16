defmodule Jido.Connect.HubSpot.Handlers.Actions.CreateDeal do
  @moduledoc false

  alias Jido.Connect.HubSpot.Handlers.Actions.ResourceHelpers

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- ResourceHelpers.fetch_client(credentials),
         token <- ResourceHelpers.credential_token(credentials),
         {:ok, deal} <- client.create_deal(input, token) do
      {:ok, %{deal: ResourceHelpers.public_map(deal)}}
    end
  end
end
