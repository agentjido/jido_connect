defmodule Jido.Connect.Asana.Handlers.Actions.ListTasks do
  @moduledoc false

  alias Jido.Connect.Asana.Client

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         token <- Client.credential_token(credentials),
         {:ok, result} <-
           client.list_tasks(token,
             project: Map.get(input, :project),
             workspace: Map.get(input, :workspace),
             assignee: Map.get(input, :assignee),
             completed_since: Map.get(input, :completed_since),
             limit: Map.get(input, :limit),
             offset: Map.get(input, :offset)
           ) do
      {:ok, result}
    end
  end

  defp fetch_client(%{asana_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}
end
