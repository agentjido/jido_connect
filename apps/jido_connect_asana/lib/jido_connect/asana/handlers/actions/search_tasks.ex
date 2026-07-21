defmodule Jido.Connect.Asana.Handlers.Actions.SearchTasks do
  @moduledoc false

  alias Jido.Connect.Asana.Client

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         token <- Client.credential_token(credentials),
         {:ok, result} <-
           client.search_tasks(input.workspace_gid, token,
             query: Map.get(input, :query),
             assignee: Map.get(input, :assignee),
             projects: Map.get(input, :projects),
             completed: Map.get(input, :completed),
             due_before: Map.get(input, :due_before),
             due_after: Map.get(input, :due_after),
             limit: Map.get(input, :limit),
             offset: Map.get(input, :offset)
           ) do
      {:ok, result}
    end
  end

  defp fetch_client(%{asana_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}
end
