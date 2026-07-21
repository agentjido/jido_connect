defmodule Jido.Connect.Nextcloud.Handlers.Actions.ListFiles do
  @moduledoc false

  alias Jido.Connect.Nextcloud.Client.WebDAV
  alias Jido.Connect.Nextcloud.Handlers.Actions.Helpers

  def run(input, runtime) do
    with {:ok, credentials} <- Helpers.credentials(runtime),
         response <-
           WebDAV.propfind(credentials, Map.get(input, :path, "/"),
             depth: Map.get(input, :depth, "1")
           ),
         {:ok, nodes} <-
           Helpers.handle_dav_nodes_response(response,
             login_name: credentials.login_name,
             base_path: Map.get(input, :path, "/"),
             skip_base?: true
           ) do
      {:ok, %{nodes: Helpers.public_map(nodes)}}
    end
  end
end
