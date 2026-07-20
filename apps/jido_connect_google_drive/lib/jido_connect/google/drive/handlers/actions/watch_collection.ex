defmodule Jido.Connect.Google.Drive.Handlers.Actions.WatchCollection do
  @moduledoc false

  alias Jido.Connect.Google.Drive.{Client, CollectionChanges}
  alias Jido.Connect.Google.Drive.Handlers.Actions.ChannelLifecycle

  def run(input, %{credentials: credentials}) do
    input = ChannelLifecycle.normalize_input(input, defaults())

    with :ok <- ChannelLifecycle.validate_watch_input(input, []),
         {:ok, client} <- fetch_client(credentials),
         access_token = Map.get(credentials, :access_token),
         {:ok, input} <- CollectionChanges.resolve_config(client, input, access_token),
         {:ok, %{start_page_token: start_page_token}} <-
           client.get_start_page_token(token_params(input), access_token),
         {:ok, channel} <-
           client.watch_changes(watch_params(input, start_page_token), access_token) do
      {:ok,
       %{
         channel: ChannelLifecycle.public_map(channel),
         checkpoint: start_page_token,
         collection_id: Map.get(input, :collection_id),
         drive_id: Map.get(input, :drive_id),
         provider: "google_drive",
         provider_resource: "changes"
       }
       |> compact()}
    end
  end

  defp token_params(input) do
    input
    |> Map.take([:drive_id, :supports_all_drives])
    |> Map.put_new(:supports_all_drives, false)
  end

  defp watch_params(input, start_page_token) do
    input
    |> Map.put(:page_token, start_page_token)
    |> Map.delete(:collection_id)
  end

  defp defaults do
    %{
      channel_type: "web_hook",
      page_size: 100,
      spaces: "drive",
      include_corpus_removals: false,
      include_items_from_all_drives: false,
      include_removed: true,
      restrict_to_my_drive: false,
      supports_all_drives: false
    }
  end

  defp compact(map) do
    map
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp fetch_client(%{google_drive_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}
end
