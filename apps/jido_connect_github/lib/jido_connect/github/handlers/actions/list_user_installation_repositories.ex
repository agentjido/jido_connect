defmodule Jido.Connect.GitHub.Handlers.Actions.ListUserInstallationRepositories do
  @moduledoc false

  alias Jido.Connect.GitHub.Handlers.Actions.Support

  def run(input, runtime) do
    with {:ok, client, token} <- Support.client_and_token(runtime),
         {:ok, result} <-
           client.list_user_installation_repositories(
             Map.fetch!(input, :installation_id),
             %{page: Map.get(input, :page, 1), per_page: Map.get(input, :per_page, 100)},
             token
           ) do
      {:ok, result}
    end
  end
end
