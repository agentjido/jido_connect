defmodule Jido.Connect.Jira.Handlers.Actions.ListProjects do
  @moduledoc false

  alias Jido.Connect.Jira.Client

  def run(input, runtime) do
    client = Client.resolve(runtime)

    with {:ok, request} <- Client.request_context(runtime),
         {:ok, result} <-
           client.list_projects(request,
             start_at: Map.get(input, :start_at, 0),
             max_results: Map.get(input, :max_results, 50)
           ) do
      {:ok, result}
    end
  end
end
