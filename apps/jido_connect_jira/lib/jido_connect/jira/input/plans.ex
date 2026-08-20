defmodule Jido.Connect.Jira.Input.Plans do
  @moduledoc false

  alias Jido.Connect.Error

  @source_types ["Board", "Project", "Filter"]
  @estimations ["StoryPoints", "Days", "Hours"]
  @date_types ["DueDate", "TargetStartDate", "TargetEndDate", "DateCustomField"]
  @inferred_dates ["None", "SprintDates", "ReleaseDates"]
  @dependencies ["Sequential", "Concurrent"]
  @max_id 2_147_483_647
  @max_nested_string 255

  def create(input) do
    with {:ok, issue_sources} <- issue_sources(Map.get(input, :issue_sources)),
         {:ok, scheduling} <- scheduling(Map.get(input, :scheduling), true),
         {:ok, exclusion_rules} <-
           optional_exclusion_rules(Map.get(input, :exclusion_rules), false),
         {:ok, cross_releases} <-
           optional_list(Map.get(input, :cross_project_releases), &cross_release/1),
         {:ok, custom_fields} <- optional_list(Map.get(input, :custom_fields), &custom_field/1),
         {:ok, permissions} <- optional_list(Map.get(input, :permissions), &permission/1) do
      {:ok,
       input
       |> Map.put(:issue_sources, issue_sources)
       |> Map.put(:scheduling, scheduling)
       |> put_optional(:exclusion_rules, exclusion_rules)
       |> put_optional(:cross_project_releases, cross_releases)
       |> put_optional(:custom_fields, custom_fields)
       |> put_optional(:permissions, permissions)}
    end
  end

  def update(input) do
    updates = input |> Map.drop([:id]) |> Enum.reject(fn {_key, value} -> is_nil(value) end)

    if updates == [] do
      invalid(:plan, "at least one plan field is required")
    else
      with {:ok, issue_sources} <- optional_issue_sources(Map.get(input, :issue_sources)),
           {:ok, scheduling} <- optional_scheduling(Map.get(input, :scheduling)),
           {:ok, exclusion_rules} <-
             optional_exclusion_rules(Map.get(input, :exclusion_rules), true),
           {:ok, cross_releases} <-
             optional_list(Map.get(input, :cross_project_releases), &cross_release/1),
           {:ok, custom_fields} <- optional_list(Map.get(input, :custom_fields), &custom_field/1),
           {:ok, permissions} <- optional_list(Map.get(input, :permissions), &permission/1) do
        {:ok,
         input
         |> put_optional(:issue_sources, issue_sources)
         |> put_optional(:scheduling, scheduling)
         |> put_optional(:exclusion_rules, exclusion_rules)
         |> put_optional(:cross_project_releases, cross_releases)
         |> put_optional(:custom_fields, custom_fields)
         |> put_optional(:permissions, permissions)}
      end
    end
  end

  defp optional_issue_sources(nil), do: {:ok, nil}
  defp optional_issue_sources(values), do: issue_sources(values)

  defp issue_sources(values) when is_list(values) and length(values) in 1..100 do
    with {:ok, normalized} <- normalize_list(values, &issue_source/1, :issue_sources),
         true <- Enum.uniq(normalized) == normalized do
      {:ok, normalized}
    else
      {:error, _error} = error -> error
      false -> invalid(:issue_sources, "issue_sources must contain unique entries")
    end
  end

  defp issue_sources(_values),
    do: invalid(:issue_sources, "issue_sources must contain 1 to 100 entries")

  defp issue_source(value) do
    with {:ok, value} <- strict(value, [:type, :value], [:type, :value]),
         type when type in @source_types <- value.type,
         true <- positive_integer?(value.value) do
      {:ok, value}
    else
      _other -> invalid(:issue_sources, "an issue source is invalid")
    end
  end

  defp optional_scheduling(nil), do: {:ok, nil}
  defp optional_scheduling(value), do: scheduling(value, false)

  defp scheduling(value, require_estimation?) do
    allowed = [:estimation, :startDate, :endDate, :inferredDates, :dependencies]
    required = if require_estimation?, do: [:estimation], else: []

    with {:ok, value} <- strict(value, allowed, required),
         true <- require_estimation? or map_size(value) > 0,
         :ok <- optional_enum(value, :estimation, @estimations),
         {:ok, start_date} <- optional_date(Map.get(value, :startDate)),
         {:ok, end_date} <- optional_date(Map.get(value, :endDate)),
         :ok <- optional_enum(value, :inferredDates, @inferred_dates),
         :ok <- optional_enum(value, :dependencies, @dependencies) do
      {:ok,
       value
       |> put_optional(:startDate, start_date)
       |> put_optional(:endDate, end_date)}
    else
      {:error, _error} = error -> error
      _other -> invalid(:scheduling, "the scheduling configuration is invalid")
    end
  end

  defp optional_date(nil), do: {:ok, nil}

  defp optional_date(value) do
    with {:ok, value} <- strict(value, [:type, :dateCustomFieldId], [:type]),
         type when type in @date_types <- value.type,
         :ok <- validate_date_custom_field(value) do
      {:ok, value}
    else
      {:error, _error} = error -> error
      _other -> invalid(:scheduling, "a plan date field is invalid")
    end
  end

  defp validate_date_custom_field(%{type: "DateCustomField", dateCustomFieldId: id})
       when is_integer(id) and id in 1..@max_id,
       do: :ok

  defp validate_date_custom_field(%{type: "DateCustomField"}),
    do: invalid(:dateCustomFieldId, "dateCustomFieldId is required")

  defp validate_date_custom_field(value) do
    if Map.has_key?(value, :dateCustomFieldId),
      do: invalid(:dateCustomFieldId, "dateCustomFieldId is valid only for DateCustomField"),
      else: :ok
  end

  defp optional_exclusion_rules(nil, _require_non_empty?), do: {:ok, nil}

  defp optional_exclusion_rules(value, require_non_empty?) do
    allowed = [
      :numberOfDaysToShowCompletedIssues,
      :issueIds,
      :workStatusIds,
      :workStatusCategoryIds,
      :issueTypeIds,
      :releaseIds
    ]

    with {:ok, value} <- strict(value, allowed, []),
         true <- not require_non_empty? or map_size(value) > 0,
         :ok <- optional_non_negative(value, :numberOfDaysToShowCompletedIssues),
         :ok <- optional_positive_id_list(value, :issueIds),
         :ok <- optional_positive_id_list(value, :workStatusIds),
         :ok <- optional_positive_id_list(value, :workStatusCategoryIds),
         :ok <- optional_positive_id_list(value, :issueTypeIds),
         :ok <- optional_positive_id_list(value, :releaseIds) do
      {:ok, value}
    else
      {:error, _error} = error -> error
      _other -> invalid(:exclusion_rules, "the exclusion rules are invalid")
    end
  end

  defp cross_release(value) do
    with {:ok, value} <- strict(value, [:name, :releaseIds], [:name, :releaseIds]),
         true <- bounded_string?(value.name),
         :ok <- positive_id_list(value.releaseIds, :releaseIds) do
      {:ok, value}
    else
      {:error, _error} = error -> error
      _other -> invalid(:cross_project_releases, "a cross-project release is invalid")
    end
  end

  defp custom_field(value) do
    with {:ok, value} <- strict(value, [:customFieldId, :filter], [:customFieldId, :filter]),
         true <- positive_integer?(value.customFieldId),
         true <- is_boolean(value.filter) do
      {:ok, value}
    else
      _other -> invalid(:custom_fields, "a custom field configuration is invalid")
    end
  end

  defp permission(value) do
    with {:ok, value} <- strict(value, [:type, :holder], [:type, :holder]),
         type when type in ["View", "Edit"] <- value.type,
         {:ok, holder} <- strict(value.holder, [:type, :value], [:type, :value]),
         holder_type when holder_type in ["Group", "AccountId"] <- holder.type,
         true <- bounded_string?(holder.value) do
      {:ok, %{type: type, holder: holder}}
    else
      {:error, _error} = error -> error
      _other -> invalid(:permissions, "a plan permission is invalid")
    end
  end

  defp optional_list(nil, _fun), do: {:ok, nil}

  defp optional_list(values, fun) when is_list(values) and length(values) <= 100 do
    normalize_list(values, fun, :plan)
  end

  defp optional_list(_values, _fun), do: invalid(:plan, "a plan list has more than 100 entries")

  defp normalize_list(values, fun, field) do
    Enum.reduce_while(values, {:ok, []}, fn value, {:ok, acc} ->
      case fun.(value) do
        {:ok, normalized} -> {:cont, {:ok, [normalized | acc]}}
        {:error, _error} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, normalized} -> {:ok, Enum.reverse(normalized)}
      {:error, _error} = error -> error
      _other -> invalid(field, "a list entry is invalid")
    end
  end

  defp strict(value, allowed, required) when is_map(value) do
    names = Map.new(allowed, &{Atom.to_string(&1), &1})

    Enum.reduce_while(value, {:ok, %{}}, fn {key, field_value}, {:ok, acc} ->
      key = if is_atom(key), do: Atom.to_string(key), else: key

      case Map.fetch(names, key) do
        {:ok, normalized_key} -> {:cont, {:ok, Map.put(acc, normalized_key, field_value)}}
        :error -> {:halt, invalid(:plan, "an unrecognized nested field was provided")}
      end
    end)
    |> case do
      {:ok, normalized} ->
        if Enum.all?(required, &Map.has_key?(normalized, &1)),
          do: {:ok, normalized},
          else: invalid(:plan, "a required nested field is missing")

      {:error, _error} = error ->
        error
    end
  end

  defp strict(_value, _allowed, _required), do: invalid(:plan, "a nested field must be an object")

  defp optional_enum(map, key, allowed) do
    case Map.fetch(map, key) do
      :error ->
        :ok

      {:ok, value} ->
        if(value in allowed, do: :ok, else: invalid(key, "the value is not allowed"))
    end
  end

  defp optional_non_negative(map, key) do
    case Map.fetch(map, key) do
      :error -> :ok
      {:ok, value} when is_integer(value) and value in 0..@max_id -> :ok
      {:ok, _value} -> invalid(key, "the value must be a non-negative integer")
    end
  end

  defp optional_positive_id_list(map, key) do
    case Map.fetch(map, key) do
      :error -> :ok
      {:ok, value} -> positive_id_list(value, key)
    end
  end

  defp positive_id_list(values, _key)
       when is_list(values) and length(values) <= 100 do
    if values != [] and Enum.all?(values, &positive_integer?/1) and Enum.uniq(values) == values,
      do: :ok,
      else: invalid(:plan, "identifier lists must contain unique positive integers")
  end

  defp positive_id_list(_values, key), do: invalid(key, "the value must be an identifier list")

  defp positive_integer?(value), do: is_integer(value) and value in 1..@max_id
  defp non_blank?(value), do: is_binary(value) and String.trim(value) != ""

  defp bounded_string?(value),
    do: non_blank?(value) and String.length(value) <= @max_nested_string

  defp put_optional(map, _key, nil), do: map
  defp put_optional(map, key, value), do: Map.put(map, key, value)

  defp invalid(field, message) do
    {:error,
     Error.validation("Invalid Jira input",
       reason: :invalid_jira_input,
       subject: field,
       details: %{field: field, message: message}
     )}
  end
end
