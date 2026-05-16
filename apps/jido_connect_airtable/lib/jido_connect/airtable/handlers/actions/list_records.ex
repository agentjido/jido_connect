defmodule Jido.Connect.Airtable.Handlers.Actions.ListRecords do
  @moduledoc false

  alias Jido.Connect.Airtable.Handlers.Actions.ResourceHelpers

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- ResourceHelpers.fetch_client(credentials),
         token <- ResourceHelpers.credential_token(credentials),
         {:ok, result} <- client.list_records(input, token) do
      {:ok, build_result(result)}
    end
  end

  defp build_result(result) do
    base = %{
      records: Enum.map(Map.get(result, :records, []), &ResourceHelpers.public_map/1)
    }

    case Map.get(result, :offset) do
      nil -> base
      offset -> Map.put(base, :offset, offset)
    end
  end
end
