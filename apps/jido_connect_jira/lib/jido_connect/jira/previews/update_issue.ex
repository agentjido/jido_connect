defmodule Jido.Connect.Jira.Previews.UpdateIssue do
  @moduledoc false

  @behaviour Jido.Connect.ActionPreview

  @impl true
  def preview(input, _context) do
    changed_fields =
      input
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Enum.map(&elem(&1, 0))
      |> List.delete(:issue_key)
      |> Enum.map(&Atom.to_string/1)
      |> Enum.sort()

    %{
      operation: "update",
      issue_key: Map.get(input, :issue_key),
      changed_fields: changed_fields,
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
