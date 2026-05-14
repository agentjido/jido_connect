defmodule Jido.Connect.Google.Sheets.Handlers.Actions.GetDeveloperMetadata do
  @moduledoc false

  alias Jido.Connect.Google.Sheets.Client

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, developer_metadata} <-
           client.get_developer_metadata(input, Map.get(credentials, :access_token)) do
      {:ok, %{developer_metadata: public_map(developer_metadata)}}
    end
  end

  defp fetch_client(%{google_sheets_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}

  defp public_map(struct) when is_struct(struct), do: struct |> Map.from_struct() |> public_map()
  defp public_map(list) when is_list(list), do: Enum.map(list, &public_map/1)

  defp public_map(map) when is_map(map),
    do: Map.new(map, fn {key, value} -> {key, public_map(value)} end)

  defp public_map(value), do: value
end
