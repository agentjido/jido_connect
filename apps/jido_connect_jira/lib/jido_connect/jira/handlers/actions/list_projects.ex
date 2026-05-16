defmodule Jido.Connect.Jira.Handlers.Actions.ListProjects do
  @moduledoc false

  alias Jido.Connect.Jira.Client

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         token <- Client.credential_token(credentials),
         {:ok, result} <-
           client.list_projects(token,
             start_at: Map.get(input, :start_at, 0),
             max_results: Map.get(input, :max_results, 50)
           ) do
      {:ok, result}
    end
  end

  defp fetch_client(%{jira_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}
end
