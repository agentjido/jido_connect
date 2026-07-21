defmodule Jido.Connect.Nextcloud.Handlers.Actions.UploadFile do
  @moduledoc false

  alias Jido.Connect.Nextcloud.Client.WebDAV
  alias Jido.Connect.Nextcloud.Handlers.Actions.Helpers

  def run(input, runtime) do
    path = Map.fetch!(input, :path)

    with {:ok, credentials} <- Helpers.credentials(runtime) do
      WebDAV.upload(credentials, path, Map.fetch!(input, :content),
        content_type: Map.get(input, :content_type, "application/octet-stream")
      )
      |> Helpers.truthy_status(
        [200, 201, 204],
        %{uploaded: true, path: path},
        "Failed to upload Nextcloud file"
      )
    end
  end
end
