defmodule Jido.Connect.Google.Drive.Handlers.Actions.WatchCollection do
  @moduledoc false

  alias Jido.Connect.Google.Drive.{Client, CollectionChanges}
  alias Jido.Connect.Google.Drive.Handlers.Actions.ChannelLifecycle

  def run(input, %{credentials: credentials}) do
    input = ChannelLifecycle.normalize_input(input, %{channel_type: "web_hook"})

    with :ok <- ChannelLifecycle.validate_watch_input(input, []),
         {:ok, client} <- fetch_client(credentials),
         access_token = Map.get(credentials, :access_token),
         {:ok, %{checkpoint: checkpoint, config: config}} <-
           CollectionChanges.start_watch_checkpoint(client, input, access_token),
         {:ok, channel} <-
           client.watch_changes(watch_params(config, checkpoint), access_token) do
      {:ok,
       %{
         channel: ChannelLifecycle.public_map(channel),
         checkpoint: checkpoint,
         collection_id: Map.get(config, :collection_id),
         drive_id: Map.get(config, :drive_id),
         provider: "google_drive",
         provider_resource: "changes"
       }
       |> compact()}
    end
  end

  defp watch_params(input, start_page_token) do
    input
    |> Map.put(:page_token, start_page_token)
    |> Map.delete(:collection_id)
  end

  defp compact(map) do
    map
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp fetch_client(%{google_drive_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}
end
