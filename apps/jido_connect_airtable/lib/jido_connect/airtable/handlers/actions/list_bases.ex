defmodule Jido.Connect.Airtable.Handlers.Actions.ListBases do
  @moduledoc false

  alias Jido.Connect.Airtable.Handlers.Actions.ResourceHelpers

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- ResourceHelpers.fetch_client(credentials),
         token <- ResourceHelpers.credential_token(credentials),
         {:ok, bases} <- client.list_bases(input, token) do
      {:ok, %{bases: Enum.map(bases, &ResourceHelpers.public_map/1)}}
    end
  end
end
