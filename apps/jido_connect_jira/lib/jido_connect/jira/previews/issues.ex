defmodule Jido.Connect.Jira.Previews.DeleteIssue do
  @moduledoc false
  @behaviour Jido.Connect.ActionPreview

  def preview(input, _context),
    do: %{operation: "delete_issue", issue_key: Map.get(input, :issue_key)}
end
