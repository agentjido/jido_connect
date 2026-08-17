defmodule Jido.Connect.Jira.Previews.AddComment do
  @moduledoc false

  @behaviour Jido.Connect.ActionPreview

  @impl true
  def preview(input, _context) do
    body = Map.get(input, :body, "")

    %{
      issue_key: Map.get(input, :issue_key),
      comment_bytes: byte_size(body)
    }
  end
end
