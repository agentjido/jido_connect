defmodule Jido.Connect.Linear.Handlers.Actions.UpdateIssue do
  @moduledoc false

  alias Jido.Connect.Linear.Client

  def run(input, %{credentials: credentials}) do
    fields = build_update_fields(input)

    with {:ok, client} <- fetch_client(credentials),
         token <- Client.credential_token(credentials),
         {:ok, result} <- client.update_issue(input.issue_id, fields, token) do
      {:ok, result}
    end
  end

  defp build_update_fields(input) do
    base = %{}

    base
    |> maybe_put(:title, Map.get(input, :title))
    |> maybe_put(:description, Map.get(input, :description))
    |> maybe_put(:priority, Map.get(input, :priority))
    |> maybe_put(:status, Map.get(input, :status))
    |> maybe_put(:assignee_id, Map.get(input, :assignee_id))
    |> maybe_put(:labels, Map.get(input, :labels))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp fetch_client(%{linear_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}
end
