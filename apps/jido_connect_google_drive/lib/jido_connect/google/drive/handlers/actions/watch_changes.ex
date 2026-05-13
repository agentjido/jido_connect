defmodule Jido.Connect.Google.Drive.Handlers.Actions.WatchChanges do
  @moduledoc false

  alias Jido.Connect.Google.Drive.Client

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, channel} <-
           client.watch_changes(normalize_input(input), Map.get(credentials, :access_token)) do
      {:ok, %{channel: public_map(channel)}}
    end
  end

  defp normalize_input(input) do
    input
    |> Map.put_new(:type, "web_hook")
    |> Map.put_new(:spaces, "drive")
    |> Map.put_new(:include_items_from_all_drives, false)
    |> Map.put_new(:include_removed, true)
    |> Map.put_new(:restrict_to_my_drive, false)
    |> Map.put_new(:supports_all_drives, false)
  end

  defp fetch_client(%{google_drive_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}

  defp public_map(struct) when is_struct(struct), do: struct |> Map.from_struct() |> public_map()
  defp public_map(map) when is_map(map), do: map
  defp public_map(value), do: value
end
