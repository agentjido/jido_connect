defmodule Jido.Connect.Google.Drive.Handlers.Actions.WatchChanges do
  @moduledoc false

  alias Jido.Connect.Google.Drive.Handlers.Actions.ChannelLifecycle

  def run(input, %{credentials: credentials}) do
    with :ok <- ChannelLifecycle.validate_watch_input(input, [:page_token]),
         {:ok, client} <- ChannelLifecycle.fetch_client(credentials),
         {:ok, channel} <-
           client.watch_changes(
             ChannelLifecycle.normalize_input(input, defaults()),
             Map.get(credentials, :access_token)
           ) do
      {:ok, %{channel: ChannelLifecycle.public_map(channel)}}
    end
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
end
