defmodule Jido.Connect.Google.Calendar.Handlers.Actions.MoveEvent do
  @moduledoc false

  alias Jido.Connect.Google.Calendar.Handlers.Actions.{EventUtilities, ResourceHelpers}

  def run(input, %{credentials: credentials}) do
    with :ok <- EventUtilities.validate_move(input),
         {:ok, client} <- ResourceHelpers.fetch_client(credentials),
         {:ok, event} <-
           client.move_event(
             EventUtilities.normalize_input(input),
             Map.get(credentials, :access_token)
           ) do
      {:ok, %{event: ResourceHelpers.public_map(event)}}
    end
  end
end
