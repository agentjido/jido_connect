defmodule Jido.Connect.Jira.Handlers.Actions.UpdateIssue do
  @moduledoc false

  alias Jido.Connect.Jira.Client

  @updatable_fields [:summary, :description, :priority, :labels, :assignee_account_id]

  def run(input, runtime) do
    attrs = build_update_fields(input)
    client = Client.resolve(runtime)

    with {:ok, request} <- Client.request_context(runtime),
         {:ok, result} <- client.update_issue(input.issue_key, attrs, request) do
      {:ok, result}
    end
  end

  defp build_update_fields(input) do
    input
    |> Map.take(@updatable_fields)
    |> Enum.reduce(%{}, fn
      {:assignee_account_id, account_id}, acc when is_binary(account_id) ->
        Map.put(acc, :assignee, %{accountId: account_id})

      {:priority, name}, acc when is_binary(name) ->
        Map.put(acc, :priority, %{name: name})

      {:description, desc}, acc when is_binary(desc) ->
        Map.put(acc, :description, doc_from_text(desc))

      {key, value}, acc ->
        Map.put(acc, key, value)
    end)
  end

  defp doc_from_text(text) do
    %{
      type: "doc",
      version: 1,
      content: [
        %{type: "paragraph", content: [%{type: "text", text: text}]}
      ]
    }
  end
end
