defmodule Jido.Connect.Airtable.Handlers.Actions.GetRecord do
  @moduledoc false

  alias Jido.Connect.Airtable.Handlers.Actions.ResourceHelpers

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- ResourceHelpers.fetch_client(credentials),
         token <- ResourceHelpers.credential_token(credentials),
         {:ok, record} <- client.get_record(input, token) do
      {:ok, %{record: ResourceHelpers.public_map(record)}}
    end
  end
end
