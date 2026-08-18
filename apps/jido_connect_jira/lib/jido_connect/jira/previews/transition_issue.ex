defmodule Jido.Connect.Jira.Previews.TransitionIssue do
  @moduledoc false

  @behaviour Jido.Connect.ActionPreview

  @impl true
  def preview(input, _context) do
    %{
      operation: "transition",
      issue_key: Map.get(input, :issue_key),
      transition_id: Map.get(input, :transition_id),
      field_names: input |> Map.get(:fields) |> field_names()
    }
  end

  defp field_names(value) when is_map(value) do
    value |> Map.keys() |> Enum.map(&to_string/1) |> Enum.sort()
  end

  defp field_names(_value), do: []
end
