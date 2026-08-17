defmodule Jido.Connect.Jira.Handlers.Actions.CreateIssue do
  @moduledoc false

  alias Jido.Connect.Jira.Client

  def run(input, runtime) do
    attrs = build_issue_fields(input)
    client = Client.resolve(runtime)

    with {:ok, request} <- Client.request_context(runtime),
         {:ok, issue} <- client.create_issue(attrs, request) do
      {:ok, issue}
    end
  end

  defp build_issue_fields(input) do
    base = %{
      project: %{key: Map.get(input, :project_key)},
      issuetype: %{name: Map.get(input, :issue_type, "Task")},
      summary: Map.get(input, :summary)
    }

    base
    |> maybe_put(:description, Map.get(input, :description))
    |> maybe_put(:labels, Map.get(input, :labels))
    |> maybe_put(:priority, priority_field(Map.get(input, :priority)))
    |> maybe_put(:assignee, assignee_field(Map.get(input, :assignee_account_id)))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp priority_field(nil), do: nil
  defp priority_field(name), do: %{name: name}

  defp assignee_field(nil), do: nil
  defp assignee_field(account_id), do: %{accountId: account_id}
end
