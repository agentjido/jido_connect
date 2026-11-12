defmodule Jido.Connect.Tempo.Handlers.Actions.ListAccountsForProject do
  @moduledoc false

  # The input carries only the project ID, which the action schema has
  # already checked; the client checks it again before its first request.

  alias Jido.Connect.Tempo.{Account, Client}

  def run(%{project_id: project_id}, runtime) do
    with {:ok, request} <- Client.request_context(runtime),
         client = Client.resolve(runtime),
         {:ok, accounts} <- client.list_accounts_for_project(request, project_id, []) do
      {:ok, %{project_id: project_id, accounts: Enum.map(accounts, &Account.to_map/1)}}
    end
  end
end
