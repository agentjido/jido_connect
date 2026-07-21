defmodule Jido.Connect.Linear.Handlers.Actions.AssignIssue do
  @moduledoc false

  alias Jido.Connect.Error
  alias Jido.Connect.Linear.Client

  @doc "Assigns a Linear issue to a user. Returns `{:ok, result}` with confirmation metadata."
  def run(input, %{credentials: credentials}) do
    with {:ok, _} <- validate_assign_input(input),
         fields <- %{assignee_id: input.assignee_id},
         {:ok, client} <- fetch_client(credentials),
         token <- Client.credential_token(credentials),
         {:ok, result} <- client.update_issue(input.issue_id, fields, token) do
      {:ok, add_confirmation(result, :assigned, input)}
    end
  end

  defp validate_assign_input(input) do
    issue_id = Map.get(input, :issue_id)
    assignee_id = Map.get(input, :assignee_id)

    cond do
      not is_binary(issue_id) or byte_size(issue_id) == 0 ->
        {:error,
         Error.validation("Linear issue_id is required",
           reason: :invalid_issue_id,
           subject: :issue_id
         )}

      not is_binary(assignee_id) or byte_size(assignee_id) == 0 ->
        {:error,
         Error.validation("Linear assignee_id is required",
           reason: :invalid_assignee_id,
           subject: :assignee_id
         )}

      true ->
        {:ok, :valid}
    end
  end

  defp add_confirmation(result, action, input) do
    meta = %{
      action: action,
      issue_id: Map.get(input, :issue_id),
      assignee_id: Map.get(input, :assignee_id)
    }

    Map.put(result, :_confirmation, meta)
  end

  defp fetch_client(%{linear_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}
end
