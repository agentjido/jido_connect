defmodule Jido.Connect.Jira.Handlers.Actions.TransitionIssue do
  @moduledoc false

  alias Jido.Connect.Jira.Client

  def run(input, runtime) do
    opts = build_transition_opts(input)
    client = Client.resolve(runtime)

    with {:ok, request} <- Client.request_context(runtime),
         {:ok, result} <-
           client.transition_issue(input.issue_key, input.transition_id, request, opts) do
      {:ok, result}
    end
  end

  defp build_transition_opts(input) do
    case Map.get(input, :fields) do
      nil -> []
      fields -> [fields: fields]
    end
  end
end
