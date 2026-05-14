defmodule Jido.Connect.Google.Drive.Handlers.Actions.StopChannel do
  @moduledoc false

  alias Jido.Connect.Google.Drive.Handlers.Actions.ChannelLifecycle

  def run(input, %{credentials: credentials}) do
    with :ok <- ChannelLifecycle.validate_stop_input(input),
         {:ok, client} <- ChannelLifecycle.fetch_client(credentials),
         {:ok, result} <-
           client.stop_channel(
             ChannelLifecycle.normalize_input(input, %{}),
             Map.get(credentials, :access_token)
           ) do
      {:ok, %{result: ChannelLifecycle.public_map(result)}}
    end
  end
end
