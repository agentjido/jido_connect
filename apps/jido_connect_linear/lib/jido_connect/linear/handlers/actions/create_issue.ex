defmodule Jido.Connect.Linear.Handlers.Actions.CreateIssue do
  @moduledoc false

  alias Jido.Connect.Linear.Client

  def run(input, %{credentials: credentials}) do
    attrs = build_issue_attrs(input)

    with {:ok, client} <- fetch_client(credentials),
         token <- Client.credential_token(credentials),
         {:ok, issue} <- client.create_issue(attrs, token) do
      {:ok, issue}
    end
  end

  defp build_issue_attrs(input) do
    base = %{
      team_id: Map.get(input, :team_id),
      title: Map.get(input, :title)
    }

    base
    |> maybe_put(:description, Map.get(input, :description))
    |> maybe_put(:priority, Map.get(input, :priority))
    |> maybe_put(:assignee_id, Map.get(input, :assignee_id))
    |> maybe_put(:labels, Map.get(input, :labels))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp fetch_client(%{linear_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}
end
