defmodule Jido.Connect.Nextcloud.Handlers.Actions.DownloadFile do
  @moduledoc false

  alias Jido.Connect.Nextcloud.Client.{Transport, WebDAV}
  alias Jido.Connect.Nextcloud.Handlers.Actions.Helpers

  def run(input, runtime) do
    with {:ok, credentials} <- Helpers.credentials(runtime) do
      case WebDAV.download(credentials, Map.fetch!(input, :path)) do
        {:ok, %{status: status, body: body} = response} when status in 200..299 ->
          {:ok,
           %{
             content: body,
             content_type: Helpers.header(response, "content-type"),
             etag: Helpers.header(response, "etag")
           }}

        other ->
          Transport.handle_error_response(other, message: "Failed to download Nextcloud file")
      end
    end
  end
end
