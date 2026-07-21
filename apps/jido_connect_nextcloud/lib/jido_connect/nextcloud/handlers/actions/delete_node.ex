defmodule Jido.Connect.Nextcloud.Handlers.Actions.DeleteNode do
  @moduledoc false

  alias Jido.Connect.Nextcloud.Client.WebDAV
  alias Jido.Connect.Nextcloud.Handlers.Actions.Helpers

  def run(input, runtime) do
    path = Map.fetch!(input, :path)

    with {:ok, credentials} <- Helpers.credentials(runtime) do
      WebDAV.delete(credentials, path)
      |> Helpers.truthy_status(
        [204],
        %{deleted: true, path: path},
        "Failed to delete Nextcloud node"
      )
    end
  end
end
