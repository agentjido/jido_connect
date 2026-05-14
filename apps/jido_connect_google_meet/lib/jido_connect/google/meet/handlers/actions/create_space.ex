defmodule Jido.Connect.Google.Meet.Handlers.Actions.CreateSpace do
  @moduledoc false

  alias Jido.Connect.Google.Meet.Handlers.Actions.{ResourceHelpers, SpaceResource}

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- ResourceHelpers.fetch_client(credentials),
         {:ok, space} <-
           client.create_space(
             SpaceResource.normalize_input(input),
             Map.get(credentials, :access_token)
           ) do
      {:ok, %{space: ResourceHelpers.public_map(space)}}
    end
  end
end
