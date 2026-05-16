defmodule Jido.Connect.HubSpot.Handlers.Actions.GetCompany do
  @moduledoc false

  alias Jido.Connect.HubSpot.Handlers.Actions.ResourceHelpers

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- ResourceHelpers.fetch_client(credentials),
         token <- ResourceHelpers.credential_token(credentials),
         {:ok, company} <- client.get_company(input, token) do
      {:ok, %{company: ResourceHelpers.public_map(company)}}
    end
  end
end
