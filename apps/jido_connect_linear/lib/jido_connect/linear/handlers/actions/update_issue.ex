defmodule Jido.Connect.Linear.Handlers.Actions.UpdateIssue do
  @moduledoc false

  alias Jido.Connect.Error
  alias Jido.Connect.Linear.Client

  @doc "Updates fields on an existing Linear issue. Returns `{:ok, result}` with confirmation metadata."
  def run(input, %{credentials: credentials}) do
    with {:ok, _} <- validate_update_input(input),
         fields <- build_update_fields(input),
         {:ok, client} <- fetch_client(credentials),
         token <- Client.credential_token(credentials),
         {:ok, result} <- client.update_issue(input.issue_id, fields, token) do
      {:ok, add_confirmation(result, :updated, input)}
    end
  end

  defp validate_update_input(input) do
    issue_id = Map.get(input, :issue_id)

    cond do
      not is_binary(issue_id) or byte_size(issue_id) == 0 ->
        {:error,
         Error.validation("Linear issue_id is required",
           reason: :invalid_issue_id,
           subject: :issue_id
         )}

      not has_update_fields?(input) ->
        {:error,
         Error.validation("At least one update field is required",
           reason: :no_update_fields,
           subject: :fields
         )}

      true ->
        {:ok, :valid}
    end
  end

  defp has_update_fields?(input) do
    update_keys = [:title, :description, :priority, :status, :assignee_id, :labels]

    Enum.any?(update_keys, fn key ->
      case Map.get(input, key) do
        nil -> false
        [] -> false
        "" -> false
        _ -> true
      end
    end)
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

  defp add_confirmation(result, action, input) do
    meta = %{
      action: action,
      issue_id: Map.get(input, :issue_id)
    }

    Map.put(result, :_confirmation, meta)
  end

  defp fetch_client(%{linear_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}
end
