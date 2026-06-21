defmodule Jido.Connect.Nextcloud.Handlers.Actions.MoveNode do
  @moduledoc false

  alias Jido.Connect.Nextcloud.Client.WebDAV
  alias Jido.Connect.Nextcloud.Handlers.Actions.Helpers

  def run(input, runtime) do
    from_path = Map.fetch!(input, :from_path)
    to_path = Map.fetch!(input, :to_path)

    with {:ok, credentials} <- Helpers.credentials(runtime) do
      WebDAV.move(credentials, from_path, to_path, overwrite: Map.get(input, :overwrite, false))
      |> Helpers.truthy_status(
        [201, 204],
        %{moved: true, from_path: from_path, to_path: to_path},
        "Failed to move Nextcloud node"
      )
    end
  end
end
