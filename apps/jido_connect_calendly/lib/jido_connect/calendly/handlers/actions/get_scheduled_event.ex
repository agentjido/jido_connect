defmodule Jido.Connect.Calendly.Handlers.Actions.GetScheduledEvent do
  @moduledoc false

  alias Jido.Connect.Calendly.Handlers.Actions.ResourceHelpers

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- ResourceHelpers.fetch_client(credentials),
         token <- ResourceHelpers.credential_token(credentials),
         {:ok, event} <- client.get_scheduled_event(input, token) do
      {:ok, %{scheduled_event: ResourceHelpers.public_map(event)}}
    end
  end
end
