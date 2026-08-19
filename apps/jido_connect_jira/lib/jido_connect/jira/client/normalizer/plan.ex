defmodule Jido.Connect.Jira.Client.Normalizer.Plan do
  @moduledoc false

  alias Jido.Connect.Jira.Client.Normalizer.{Collection, Value}

  def list(payload, defaults) when is_map(payload) do
    values = Value.get(payload, :values)

    with true <- is_list(values),
         {:ok, plans} <- Collection.normalize_all(values, &one/1),
         {:ok, limit} <- Value.positive(Value.get(payload, :maxResults) || defaults[:limit]),
         {:ok, total} <- Value.optional_non_negative(Value.get(payload, :total)),
         {:ok, next_cursor} <- Value.optional_cursor(Value.get(payload, :nextPageCursor)),
         {:ok, is_last} <- Value.optional_boolean(Value.get(payload, :isLast)) do
      {:ok,
       %{plans: plans, limit: limit, total: total, next_cursor: next_cursor, is_last: is_last}}
    else
      _other -> :error
    end
  end

  def list(_payload, _defaults), do: :error

  def one(payload) when is_map(payload) do
    with {:ok, id} <- Value.id(Value.get(payload, :id)),
         {:ok, name} <- Value.required_string(Value.get(payload, :name)),
         {:ok, status} <- Value.required_string(Value.get(payload, :status)),
         {:ok, scenario_id} <- optional_id(Value.get(payload, :scenarioId)),
         {:ok, last_saved_at} <- Value.optional_string(Value.get(payload, :lastSaved)),
         {:ok, lead_account_id} <- Value.optional_string(Value.get(payload, :leadAccountId)),
         {:ok, issue_sources} <- issue_sources(Value.get(payload, :issueSources)),
         {:ok, scheduling} <- Value.optional_map(Value.get(payload, :scheduling)),
         {:ok, exclusion_rules} <- Value.optional_map(Value.get(payload, :exclusionRules)),
         {:ok, cross_project_releases} <-
           Value.optional_map_list(Value.get(payload, :crossProjectReleases)),
         {:ok, custom_fields} <- Value.optional_map_list(Value.get(payload, :customFields)),
         {:ok, permissions} <- Value.optional_map_list(Value.get(payload, :permissions)) do
      {:ok,
       %{
         id: id,
         name: name,
         status: status,
         scenario_id: scenario_id,
         last_saved_at: last_saved_at,
         lead_account_id: lead_account_id,
         issue_sources: issue_sources,
         scheduling: scheduling,
         exclusion_rules: exclusion_rules,
         cross_project_releases: cross_project_releases,
         custom_fields: custom_fields,
         permissions: permissions
       }}
    else
      _other -> :error
    end
  end

  def one(_payload), do: :error

  def created_id(payload), do: Value.id(payload)

  defp optional_id(nil), do: {:ok, nil}
  defp optional_id(value), do: Value.id(value)

  defp issue_sources(nil), do: {:ok, []}

  defp issue_sources(values) when is_list(values) do
    Collection.normalize_all(values, fn value ->
      with true <- is_map(value),
           {:ok, type} <- Value.required_string(Value.get(value, :type)),
           {:ok, id} <- Value.id(Value.get(value, :value)) do
        {:ok, %{type: type, value: id}}
      else
        _other -> :error
      end
    end)
  end

  defp issue_sources(_value), do: :error
end
