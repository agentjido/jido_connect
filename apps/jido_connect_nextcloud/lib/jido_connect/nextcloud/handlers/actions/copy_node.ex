defmodule Jido.Connect.Nextcloud.Handlers.Actions.CopyNode do
  @moduledoc false

  alias Jido.Connect.Nextcloud.Client.WebDAV
  alias Jido.Connect.Nextcloud.Handlers.Actions.Helpers

  def run(input, runtime) do
    from_path = Map.fetch!(input, :from_path)
    to_path = Map.fetch!(input, :to_path)

    with {:ok, credentials} <- Helpers.credentials(runtime) do
      WebDAV.copy(credentials, from_path, to_path, overwrite: Map.get(input, :overwrite, false))
      |> Helpers.truthy_status(
        [201, 204],
        %{copied: true, from_path: from_path, to_path: to_path},
        "Failed to copy Nextcloud node"
      )
    end
  end
end
