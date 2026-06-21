defmodule Jido.Connect.Nextcloud.Handlers.Actions.CreateFolder do
  @moduledoc false

  alias Jido.Connect.Nextcloud.Client.WebDAV
  alias Jido.Connect.Nextcloud.Handlers.Actions.Helpers

  def run(input, runtime) do
    path = Map.fetch!(input, :path)

    with {:ok, credentials} <- Helpers.credentials(runtime) do
      WebDAV.mkcol(credentials, path)
      |> Helpers.truthy_status(
        [201],
        %{created: true, path: path},
        "Failed to create Nextcloud folder"
      )
    end
  end
end
