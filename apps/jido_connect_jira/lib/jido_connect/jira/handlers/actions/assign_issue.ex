defmodule Jido.Connect.Jira.Handlers.Actions.AssignIssue do
  @moduledoc false

  alias Jido.Connect.Error
  alias Jido.Connect.Jira.Client

  def run(input, %{credentials: credentials}) do
    with {:ok, account_id} <- validate_account_id(Map.get(input, :account_id)),
         {:ok, client} <- fetch_client(credentials),
         token <- Client.credential_token(credentials),
         {:ok, result} <- client.assign_issue(input.issue_key, account_id, token) do
      {:ok, result}
    end
  end

  defp validate_account_id(account_id)
       when is_binary(account_id) and byte_size(account_id) > 0 do
    {:ok, account_id}
  end

  defp validate_account_id(_account_id) do
    {:error,
     Error.validation("Jira assignee account_id is required",
       reason: :invalid_assignee,
       subject: :account_id
     )}
  end

  defp fetch_client(%{jira_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}
end
