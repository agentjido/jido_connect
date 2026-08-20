defmodule Jido.Connect.Jira.Previews.UpdateIssue do
  @moduledoc false

  @behaviour Jido.Connect.ActionPreview

  alias Jido.Connect.Jira.Previews.Support

  @impl true
  def preview(input, _context) do
    %{
      operation: "update",
      issue_key: Map.get(input, :issue_key),
      changed_fields: Support.changed_fields(input, [:issue_key]),
      summary: Map.get(input, :summary),
      description_bytes: input |> Map.get(:description) |> Support.byte_count(),
      label_count: input |> Map.get(:labels) |> Support.item_count(),
      priority: Map.get(input, :priority),
      assignee_account_id: Map.get(input, :assignee_account_id)
    }
  end
end
