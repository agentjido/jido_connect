defmodule Jido.Connect.Nextcloud.Handlers.Actions.GetFile do
  @moduledoc false

  alias Jido.Connect.Nextcloud.Client.WebDAV
  alias Jido.Connect.Nextcloud.Handlers.Actions.Helpers

  def run(input, runtime) do
    with {:ok, credentials} <- Helpers.credentials(runtime),
         response <- WebDAV.propfind(credentials, Map.fetch!(input, :path), depth: "0"),
         {:ok, [node | _]} <-
           Helpers.handle_dav_nodes_response(response,
             login_name: credentials.login_name,
             base_path: Map.fetch!(input, :path)
           ) do
      {:ok, %{node: Helpers.public_map(node)}}
    end
  end
end
