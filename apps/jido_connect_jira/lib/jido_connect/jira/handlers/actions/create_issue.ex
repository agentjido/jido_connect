defmodule Jido.Connect.Jira.Handlers.Actions.CreateIssue do
  @moduledoc false

  alias Jido.Connect.Jira.Client

  def run(input, %{credentials: credentials}) do
    attrs = build_issue_fields(input)

    with {:ok, client} <- fetch_client(credentials),
         token <- Client.credential_token(credentials),
         {:ok, issue} <- client.create_issue(attrs, token) do
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

  defp fetch_client(%{jira_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}
end
