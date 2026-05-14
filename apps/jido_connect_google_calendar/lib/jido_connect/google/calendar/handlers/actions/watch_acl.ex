defmodule Jido.Connect.Google.Calendar.Handlers.Actions.WatchAcl do
  @moduledoc false

  alias Jido.Connect.Google.Calendar.Handlers.Actions.ChannelLifecycle

  def run(input, %{credentials: credentials}) do
    with :ok <- ChannelLifecycle.validate_watch_input(input, [:calendar_id]),
         {:ok, client} <- ChannelLifecycle.fetch_client(credentials),
         {:ok, channel} <-
           client.watch_acl(
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
