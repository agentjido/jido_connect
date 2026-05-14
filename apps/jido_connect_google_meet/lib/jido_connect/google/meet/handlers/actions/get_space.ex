defmodule Jido.Connect.Google.Meet.Handlers.Actions.GetSpace do
  @moduledoc false

  alias Jido.Connect.Google.Meet.Handlers.Actions.{ResourceHelpers, SpaceResource}

  def run(input, %{credentials: credentials}) do
    with :ok <- SpaceResource.validate_required(input, [:space_name]),
         {:ok, client} <- ResourceHelpers.fetch_client(credentials),
         {:ok, space} <-
           client.get_space(
             SpaceResource.normalize_input(input),
             Map.get(credentials, :access_token)
           ) do
      {:ok, %{space: ResourceHelpers.public_map(space)}}
    end
  end
end
