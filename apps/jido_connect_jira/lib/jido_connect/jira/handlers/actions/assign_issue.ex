defmodule Jido.Connect.Jira.Handlers.Actions.AssignIssue do
  @moduledoc false

  alias Jido.Connect.Error
  alias Jido.Connect.Jira.Client

  def run(input, runtime) do
    client = Client.resolve(runtime)

    with {:ok, account_id} <- validate_account_id(Map.get(input, :account_id)),
         {:ok, request} <- Client.request_context(runtime),
         {:ok, result} <- client.assign_issue(input.issue_key, account_id, request) do
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
end
