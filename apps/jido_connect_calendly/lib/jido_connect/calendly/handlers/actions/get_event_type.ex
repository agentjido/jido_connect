defmodule Jido.Connect.Calendly.Handlers.Actions.GetEventType do
  @moduledoc false

  alias Jido.Connect.Calendly.Handlers.Actions.ResourceHelpers

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- ResourceHelpers.fetch_client(credentials),
         token <- ResourceHelpers.credential_token(credentials),
         {:ok, event_type} <- client.get_event_type(input, token) do
      {:ok, %{event_type: ResourceHelpers.public_map(event_type)}}
    end
  end
end
