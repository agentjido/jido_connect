defmodule Jido.Connect.Jira.Handlers.Actions.GetIssue do
  @moduledoc false

  alias Jido.Connect.Jira.Client

  def run(input, runtime) do
    client = Client.resolve(runtime)

    with {:ok, request} <- Client.request_context(runtime),
         {:ok, issue} <-
           client.get_issue(input.issue_key, request, fields: Map.get(input, :fields)) do
      {:ok, issue}
    end
  end
end
