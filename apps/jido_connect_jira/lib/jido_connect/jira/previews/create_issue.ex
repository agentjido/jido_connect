defmodule Jido.Connect.Jira.Previews.CreateIssue do
  @moduledoc false

  @behaviour Jido.Connect.ActionPreview

  alias Jido.Connect.Jira.Previews.Support

  @impl true
  def preview(input, _context) do
    %{
      operation: "create",
      project_key: Map.get(input, :project_key),
      issue_type: Map.get(input, :issue_type),
      summary: Map.get(input, :summary),
      description_bytes: input |> Map.get(:description) |> Support.byte_count(),
      label_count: input |> Map.get(:labels) |> Support.item_count(),
      priority: Map.get(input, :priority),
      assignee_account_id: Map.get(input, :assignee_account_id)
    }
  end
end
