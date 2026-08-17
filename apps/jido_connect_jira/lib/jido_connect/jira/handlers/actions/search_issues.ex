defmodule Jido.Connect.Jira.Handlers.Actions.SearchIssues do
  @moduledoc false

  alias Jido.Connect.Jira.Client

  def run(input, runtime) do
    client = Client.resolve(runtime)

    with {:ok, request} <- Client.request_context(runtime),
         {:ok, result} <-
           client.search_issues(input.jql, request,
             max_results: Map.get(input, :max_results, 50),
             start_at: Map.get(input, :start_at, 0),
             fields: Map.get(input, :fields)
           ) do
      {:ok, result}
    end
  end
end
