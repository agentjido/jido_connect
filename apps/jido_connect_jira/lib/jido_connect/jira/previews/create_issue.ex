defmodule Jido.Connect.Jira.Previews.CreateIssue do
  @moduledoc false

  @behaviour Jido.Connect.ActionPreview

  @impl true
  def preview(input, _context) do
    %{
      operation: "create",
      project_key: Map.get(input, :project_key),
      issue_type: Map.get(input, :issue_type),
      summary: Map.get(input, :summary),
      description_bytes: input |> Map.get(:description) |> byte_count(),
      label_count: input |> Map.get(:labels) |> item_count(),
      priority: Map.get(input, :priority),
      assignee_account_id: Map.get(input, :assignee_account_id)
    }
  end

  defp byte_count(value) when is_binary(value), do: byte_size(value)
  defp byte_count(_value), do: 0

  defp item_count(value) when is_list(value), do: length(value)
  defp item_count(_value), do: 0
end
