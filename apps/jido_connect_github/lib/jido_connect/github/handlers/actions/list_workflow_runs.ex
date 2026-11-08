defmodule Jido.Connect.GitHub.Handlers.Actions.ListWorkflowRuns do
  @moduledoc false

  alias Jido.Connect.Error

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, %{workflow_runs: workflow_runs, total_count: total_count}} <-
           client.list_workflow_runs(
             workflow_run_params(input),
             Map.get(credentials, :access_token)
           ) do
      {:ok,
       %{
         workflow_runs: Enum.map(workflow_runs, &normalize_workflow_run/1),
         total_count: total_count,
         page:
           Jido.Connect.GitHub.Handlers.Actions.Support.page(
             input,
             length(workflow_runs),
             total_count
           )
       }}
    end
  end

  defp fetch_client(%{github_client: client}) when is_atom(client), do: {:ok, client}

  defp fetch_client(_credentials) do
    {:error, Error.config("GitHub client module is required", key: :github_client)}
  end

  defp workflow_run_params(input) do
    %{
      repo: Map.fetch!(input, :repo),
      workflow: Map.get(input, :workflow),
      branch: Map.get(input, :branch),
      status: Map.get(input, :status),
      event: Map.get(input, :event),
      page: Map.get(input, :page, 1),
      per_page: Map.get(input, :per_page, 30)
    }
  end

  defp normalize_workflow_run(workflow_run) do
    %{
      id: Map.fetch!(workflow_run, :id),
      name: Map.get(workflow_run, :name),
      number: Map.get(workflow_run, :number),
      status: Map.get(workflow_run, :status),
      conclusion: Map.get(workflow_run, :conclusion),
      event: Map.get(workflow_run, :event),
      branch: Map.get(workflow_run, :branch),
      sha: Map.get(workflow_run, :sha),
      workflow_id: Map.get(workflow_run, :workflow_id),
      attempt: Map.get(workflow_run, :attempt),
      url: Map.get(workflow_run, :url),
      created_at: Map.get(workflow_run, :created_at),
      updated_at: Map.get(workflow_run, :updated_at)
    }
  end
end
