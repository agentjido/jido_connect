defmodule Jido.Connect.GitHub.Handlers.Actions.ListIssues do
  @moduledoc false

  alias Jido.Connect.Error

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, result} <- list_page(client, input, credentials) do
      {:ok, result}
    end
  end

  defp list_page(client, input, credentials) do
    token = Map.get(credentials, :access_token)

    if function_exported?(client, :list_issues_page, 2) do
      client.list_issues_page(
        %{
          repo: Map.fetch!(input, :repo),
          state: Map.get(input, :state, "open"),
          page: Map.get(input, :page, 1),
          per_page: Map.get(input, :per_page, 100)
        },
        token
      )
    else
      with {:ok, issues} <-
             client.list_issues(
               Map.fetch!(input, :repo),
               Map.get(input, :state, "open"),
               token
             ) do
        {:ok,
         %{
           issues: Enum.map(issues, &normalize_issue/1),
           page: Jido.Connect.GitHub.Handlers.Actions.Support.page(input, length(issues))
         }}
      end
    end
  end

  defp fetch_client(%{github_client: client}) when is_atom(client), do: {:ok, client}

  defp fetch_client(_credentials) do
    {:error, Error.config("GitHub client module is required", key: :github_client)}
  end

  defp normalize_issue(issue) do
    %{
      number: Map.fetch!(issue, :number),
      url: Map.fetch!(issue, :url),
      title: Map.fetch!(issue, :title),
      state: Map.fetch!(issue, :state)
    }
  end
end
