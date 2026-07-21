defmodule Jido.Connect.Google.Drive.Handlers.Actions.ListChanges do
  @moduledoc false

  alias Jido.Connect.Google.Drive.Client

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, result} <-
           client.list_changes(normalize_input(input), Map.get(credentials, :access_token)) do
      {:ok,
       %{
         changes: Enum.map(Map.get(result, :changes, []), &public_map/1),
         next_page_token: Map.get(result, :next_page_token),
         new_start_page_token: Map.get(result, :new_start_page_token)
       }
       |> Enum.reject(fn {_key, value} -> is_nil(value) end)
       |> Map.new()}
    end
  end

  defp normalize_input(input) do
    input
    |> Map.put_new(:page_size, 100)
    |> Map.put_new(:spaces, "drive")
    |> Map.put_new(:include_items_from_all_drives, false)
    |> Map.put_new(:include_removed, true)
    |> Map.put_new(:restrict_to_my_drive, false)
    |> Map.put_new(:supports_all_drives, false)
  end

  defp fetch_client(%{google_drive_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}

  defp public_map(struct) when is_struct(struct), do: struct |> Map.from_struct() |> public_map()
  defp public_map(list) when is_list(list), do: Enum.map(list, &public_map/1)

  defp public_map(map) when is_map(map) do
    map
    |> update_present(:owners)
    |> update_present(:permissions)
    |> update_present(:file)
  end

  defp public_map(value), do: value

  defp update_present(map, key) do
    if Map.has_key?(map, key) do
      Map.update!(map, key, &public_map/1)
    else
      map
    end
  end
end
