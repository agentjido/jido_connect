defmodule Jido.Connect.Linear.Handlers.Actions.CreateIssue do
  @moduledoc false

  alias Jido.Connect.Error
  alias Jido.Connect.Linear.Client

  @doc "Creates a new Linear issue. Returns `{:ok, issue}` with confirmation metadata."
  def run(input, %{credentials: credentials}) do
    with {:ok, _} <- validate_create_input(input),
         attrs <- build_issue_attrs(input),
         {:ok, client} <- fetch_client(credentials),
         token <- Client.credential_token(credentials),
         {:ok, issue} <- client.create_issue(attrs, token) do
      {:ok, add_confirmation(issue, :created, input)}
    end
  end

  defp validate_create_input(input) do
    team_id = Map.get(input, :team_id)
    title = Map.get(input, :title)

    cond do
      not is_binary(team_id) or byte_size(team_id) == 0 ->
        {:error,
         Error.validation("Linear team_id is required",
           reason: :invalid_team_id,
           subject: :team_id
         )}

      not is_binary(title) or byte_size(title) == 0 ->
        {:error,
         Error.validation("Linear issue title is required",
           reason: :invalid_title,
           subject: :title
         )}

      true ->
        {:ok, :valid}
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

  defp add_confirmation(result, action, input) do
    meta = %{
      action: action,
      team_id: Map.get(input, :team_id),
      title: Map.get(input, :title)
    }

    Map.put(result, :_confirmation, meta)
  end

  defp fetch_client(%{linear_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}
end
