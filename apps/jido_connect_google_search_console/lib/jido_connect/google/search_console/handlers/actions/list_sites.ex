defmodule Jido.Connect.Google.SearchConsole.Handlers.Actions.ListSites do
  @moduledoc false

  alias Jido.Connect.Google.SearchConsole.Handlers.Actions.ResourceHelpers

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- ResourceHelpers.fetch_client(credentials),
         {:ok, result} <-
           client.list_sites(normalize_input(input), Map.get(credentials, :access_token)) do
      {:ok,
       %{
         sites: Enum.map(Map.get(result, :sites, []), &ResourceHelpers.public_map/1)
       }
       |> Enum.reject(fn {_key, value} -> is_nil(value) end)
       |> Map.new()}
    end
  end

  defp normalize_input(input) do
    input
    |> Map.take([:fields])
  end
end
