defmodule Jido.Connect.Jira.Handlers.Actions.SearchIssues do
  @moduledoc false

  alias Jido.Connect.Jira.Client

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         token <- Client.credential_token(credentials),
         {:ok, result} <-
           client.search_issues(input.jql, token,
             max_results: Map.get(input, :max_results, 50),
             start_at: Map.get(input, :start_at, 0)
           ) do
      {:ok, result}
    end
  end

  defp fetch_client(%{jira_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}
end
