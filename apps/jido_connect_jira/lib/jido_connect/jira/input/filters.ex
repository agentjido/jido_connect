defmodule Jido.Connect.Jira.Input.Filters do
  @moduledoc false

  alias Jido.Connect.Error

  def columns(input) do
    case Map.get(input, :columns) do
      columns when is_list(columns) and length(columns) in 1..100 ->
        if Enum.all?(columns, &(non_blank?(&1) and String.length(&1) <= 255)) and
             Enum.uniq(columns) == columns,
           do: {:ok, input},
           else: invalid(:columns, "columns must contain unique non-blank field IDs")

      _other ->
        invalid(:columns, "columns must contain between 1 and 100 field IDs")
    end
  end

  def share(input) do
    scope = Map.get(input, :scope)
    projects = Map.get(input, :projects)
    group_ids = Map.get(input, :group_ids)

    with :ok <- validate_share_targets(scope, projects, group_ids) do
      {:ok, input}
    end
  end

  defp validate_share_targets("projects", projects, nil), do: target_list(projects, :projects)
  defp validate_share_targets("groups", nil, group_ids), do: target_list(group_ids, :group_ids)

  defp validate_share_targets(scope, nil, nil)
       when scope in ["private", "authenticated", "public"],
       do: :ok

  defp validate_share_targets(_scope, _projects, _group_ids),
    do: invalid(:scope, "share targets must match the selected scope")

  defp target_list(values, field) when is_list(values) and length(values) in 1..100 do
    if Enum.all?(values, &(non_blank?(&1) and String.length(&1) <= 255)) and
         Enum.uniq(values) == values,
       do: :ok,
       else: invalid(field, "share targets must be unique non-blank identifiers")
  end

  defp target_list(_values, field), do: invalid(field, "share targets are required")

  defp non_blank?(value), do: is_binary(value) and String.trim(value) != ""

  defp invalid(field, message) do
    {:error,
     Error.validation("Invalid Jira input",
       reason: :invalid_jira_input,
       subject: field,
       details: %{field: field, message: message}
     )}
  end
end
