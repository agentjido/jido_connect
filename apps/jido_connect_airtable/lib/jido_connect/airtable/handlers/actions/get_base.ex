defmodule Jido.Connect.Airtable.Handlers.Actions.GetBase do
  @moduledoc false

  alias Jido.Connect.Airtable.Handlers.Actions.ResourceHelpers

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- ResourceHelpers.fetch_client(credentials),
         token <- ResourceHelpers.credential_token(credentials),
         {:ok, base} <- client.get_base(input, token) do
      {:ok, %{base: ResourceHelpers.public_map(base)}}
    end
  end
end
