defmodule Jido.Connect.Nextcloud.Handlers.Actions.SearchFiles do
  @moduledoc false

  alias Jido.Connect.Nextcloud.Client.WebDAV
  alias Jido.Connect.Nextcloud.Handlers.Actions.Helpers

  def run(input, runtime) do
    with {:ok, credentials} <- Helpers.credentials(runtime),
         response <-
           WebDAV.search(credentials, Map.fetch!(input, :query),
             scope_path: Map.get(input, :scope_path, "/")
           ),
         {:ok, nodes} <-
           Helpers.handle_dav_nodes_response(response, login_name: credentials.login_name) do
      {:ok, %{nodes: Helpers.public_map(nodes)}}
    end
  end
end
