defmodule Jido.Connect.Google.Calendar.Handlers.Actions.WatchSettings do
  @moduledoc false

  alias Jido.Connect.Google.Calendar.Handlers.Actions.ChannelLifecycle

  def run(input, %{credentials: credentials}) do
    with :ok <- ChannelLifecycle.validate_watch_input(input, []),
         {:ok, client} <- ChannelLifecycle.fetch_client(credentials),
         {:ok, channel} <-
           client.watch_settings(
             ChannelLifecycle.normalize_input(input, defaults()),
             Map.get(credentials, :access_token)
           ) do
      {:ok, %{channel: ChannelLifecycle.public_map(channel)}}
    end
  end

  defp defaults do
    %{
      channel_type: "web_hook"
    }
  end
end
