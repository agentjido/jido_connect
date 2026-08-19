defmodule Jido.Connect.Jira.Previews.AssignIssue do
  @moduledoc false

  @behaviour Jido.Connect.ActionPreview

  @impl true
  def preview(input, _context) do
    %{
      operation: "assign",
      issue_key: Map.get(input, :issue_key),
      account_id: Map.get(input, :account_id)
    }
  end
end
