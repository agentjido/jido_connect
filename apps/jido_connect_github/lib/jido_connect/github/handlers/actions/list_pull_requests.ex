defmodule Jido.Connect.GitHub.Handlers.Actions.ListPullRequests do
  @moduledoc false

  alias Jido.Connect.Error

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, pull_requests} <-
           client.list_pull_requests(
             pull_request_params(input),
             Map.get(credentials, :access_token)
           ) do
      {:ok,
       %{
         pull_requests: pull_requests,
         page: Jido.Connect.GitHub.Handlers.Actions.Support.page(input, length(pull_requests))
       }}
    end
  end

  defp fetch_client(%{github_client: client}) when is_atom(client), do: {:ok, client}

  defp fetch_client(_credentials) do
    {:error, Error.config("GitHub client module is required", key: :github_client)}
  end

  defp pull_request_params(input) do
    %{
      repo: Map.fetch!(input, :repo),
      state: Map.get(input, :state, "open"),
      head: Map.get(input, :head),
      base: Map.get(input, :base),
      sort: Map.get(input, :sort, "created"),
      direction: Map.get(input, :direction, "desc"),
      page: Map.get(input, :page, 1),
      per_page: Map.get(input, :per_page, 30)
    }
  end
end
