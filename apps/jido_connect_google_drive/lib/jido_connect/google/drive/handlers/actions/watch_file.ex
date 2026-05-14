defmodule Jido.Connect.Google.Drive.Handlers.Actions.WatchFile do
  @moduledoc false

  alias Jido.Connect.Google.Drive.Handlers.Actions.ChannelLifecycle

  def run(input, %{credentials: credentials}) do
    with :ok <- ChannelLifecycle.validate_watch_input(input, [:file_id]),
         {:ok, client} <- ChannelLifecycle.fetch_client(credentials),
         {:ok, channel} <-
           client.watch_file(
             ChannelLifecycle.normalize_input(input, defaults()),
             Map.get(credentials, :access_token)
           ) do
      {:ok, %{channel: ChannelLifecycle.public_map(channel)}}
    end
  end

  defp defaults do
    %{
      channel_type: "web_hook",
      acknowledge_abuse: false,
      supports_all_drives: false
    }
  end
end
