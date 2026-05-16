defmodule Jido.Connect.Linear.Handlers.Actions.SetIssueStatus do
  @moduledoc false

  alias Jido.Connect.Error
  alias Jido.Connect.Linear.Client

  @doc "Changes the status of a Linear issue. Returns `{:ok, result}` with confirmation metadata."
  def run(input, %{credentials: credentials}) do
    with {:ok, _} <- validate_status_input(input),
         fields <- %{status: input.status},
         {:ok, client} <- fetch_client(credentials),
         token <- Client.credential_token(credentials),
         {:ok, result} <- client.update_issue(input.issue_id, fields, token) do
      {:ok, add_confirmation(result, :status_changed, input)}
    end
  end

  defp validate_status_input(input) do
    issue_id = Map.get(input, :issue_id)
    status = Map.get(input, :status)

    cond do
      not is_binary(issue_id) or byte_size(issue_id) == 0 ->
        {:error,
         Error.validation("Linear issue_id is required",
           reason: :invalid_issue_id,
           subject: :issue_id
         )}

      not is_binary(status) or byte_size(status) == 0 ->
        {:error,
         Error.validation("Linear status is required",
           reason: :invalid_status,
           subject: :status
         )}

      true ->
        {:ok, :valid}
    end
  end

  defp add_confirmation(result, action, input) do
    meta = %{
      action: action,
      issue_id: Map.get(input, :issue_id),
      status: Map.get(input, :status)
    }

    Map.put(result, :_confirmation, meta)
  end

  defp fetch_client(%{linear_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}
end
