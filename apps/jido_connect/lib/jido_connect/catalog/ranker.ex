defmodule Jido.Connect.Catalog.Ranker do
  @moduledoc false

  alias Jido.Connect.{Callback, Error, Sanitizer}

  alias Jido.Connect.Catalog.{
    Item,
    ItemLookup,
    ItemSearchResult,
    Serializer,
    ToolEntry,
    ToolLookup,
    ToolSearchResult
  }

  @spec apply([ToolSearchResult.t()] | [ItemSearchResult.t()], String.t() | nil, term()) ::
          [ToolSearchResult.t()] | [ItemSearchResult.t()]
  def apply(results, _query, ranker) when ranker in [nil, false], do: results

  def apply(results, query, ranker) do
    candidates = Enum.map(results, &candidate_payload/1)

    case call_ranker(ranker, query, candidates) do
      {:ok, refs} ->
        reorder_results(results, refs)

      {:error, error} ->
        annotate_fallback(results, error)
    end
  end

  defp call_ranker(ranker, query, candidates) do
    sanitized_candidates = Sanitizer.sanitize(candidates, :transport)

    with {:ok, result} <-
           Callback.run(fn -> invoke_ranker(ranker, query, sanitized_candidates) end,
             phase: :catalog_ranker,
             details: ranker_details(ranker)
           ) do
      normalize_ranker_result(result)
    end
  end

  defp invoke_ranker(fun, query, candidates) when is_function(fun, 2), do: fun.(query, candidates)

  defp invoke_ranker(module, query, candidates) when is_atom(module) do
    if function_exported?(module, :rank, 2) do
      Kernel.apply(module, :rank, [query, candidates])
    else
      raise ArgumentError, "catalog ranker module must export rank/2"
    end
  end

  defp invoke_ranker({module, function}, query, candidates)
       when is_atom(module) and is_atom(function) do
    Kernel.apply(module, function, [query, candidates])
  end

  defp invoke_ranker({module, function, extra_args}, query, candidates)
       when is_atom(module) and is_atom(function) and is_list(extra_args) do
    Kernel.apply(module, function, [query, candidates | extra_args])
  end

  defp invoke_ranker(other, _query, _candidates) do
    raise ArgumentError, "invalid catalog ranker: #{inspect(other)}"
  end

  defp normalize_ranker_result({:ok, refs}) when is_list(refs), do: {:ok, refs}
  defp normalize_ranker_result(refs) when is_list(refs), do: {:ok, refs}

  defp normalize_ranker_result(other) do
    {:error,
     Error.execution("Catalog ranker returned an invalid result",
       phase: :catalog_ranker,
       details: %{returned: Sanitizer.sanitize(other, :transport)}
     )}
  end

  defp reorder_results(results, refs) do
    result_by_key = Map.new(results, &{subject_key(result_subject(&1)), &1})
    subjects = Enum.map(results, &result_subject/1)

    {ranked, seen} =
      refs
      |> Enum.map(&resolve_ref(&1, subjects))
      |> Enum.reject(&is_nil/1)
      |> Enum.reduce({[], MapSet.new()}, fn {key, reason}, {acc, seen} ->
        cond do
          MapSet.member?(seen, key) ->
            {acc, seen}

          result = Map.get(result_by_key, key) ->
            {[with_ranker_metadata(result, length(acc) + 1, reason) | acc], MapSet.put(seen, key)}

          true ->
            {acc, seen}
        end
      end)

    remaining =
      Enum.reject(results, fn result ->
        MapSet.member?(seen, subject_key(result_subject(result)))
      end)

    Enum.reverse(ranked) ++ remaining
  end

  defp resolve_ref(ref, subjects) do
    case subject_lookup(subjects, ranker_subject_ref(ref)) do
      {:ok, subject} -> {subject_key(subject), ranker_reason(ref)}
      {:error, _error} -> nil
    end
  end

  defp ranker_subject_ref({provider, id}), do: {provider, id}
  defp ranker_subject_ref({provider, type, id}), do: {provider, type, id}

  defp ranker_subject_ref(%{} = ref) do
    stable_ref = Map.get(ref, :ref) || Map.get(ref, "ref")
    provider = Map.get(ref, :provider) || Map.get(ref, "provider")
    type = Map.get(ref, :type) || Map.get(ref, "type")

    id =
      Map.get(ref, :id) || Map.get(ref, "id") || Map.get(ref, :tool_id) || Map.get(ref, "tool_id")

    cond do
      stable_ref -> stable_ref
      provider && type && id -> {provider, normalize_type(type), id}
      provider && id -> {provider, id}
      true -> id
    end
  end

  defp ranker_subject_ref(ref), do: ref

  defp ranker_reason(%{} = ref), do: Map.get(ref, :reason) || Map.get(ref, "reason")
  defp ranker_reason(_ref), do: nil

  defp with_ranker_metadata(result, rank, nil) do
    update_ranker_metadata(result, %{rank: rank})
  end

  defp with_ranker_metadata(result, rank, reason) do
    update_ranker_metadata(result, %{rank: rank, reason: reason})
  end

  defp annotate_fallback(results, error) do
    Enum.map(results, fn result ->
      update_ranker_metadata(result, %{status: :fallback, error: Error.to_map(error)})
    end)
  end

  defp update_ranker_metadata(result, ranker_metadata) do
    %{
      result
      | metadata:
          Map.update(result.metadata, :ranker, ranker_metadata, &Map.merge(&1, ranker_metadata))
    }
  end

  defp candidate_payload(%ToolSearchResult{} = result) do
    %{
      tool: Serializer.to_map(result.tool),
      score: result.score,
      matched_fields: result.matched_fields
    }
  end

  defp candidate_payload(%ItemSearchResult{} = result) do
    %{
      tool: Serializer.to_map(result.item),
      score: result.score,
      matched_fields: result.matched_fields
    }
  end

  defp result_subject(%ToolSearchResult{tool: tool}), do: tool
  defp result_subject(%ItemSearchResult{item: item}), do: item

  defp subject_lookup([%Item{} | _] = items, ref), do: ItemLookup.lookup(items, ref)
  defp subject_lookup([%ToolEntry{} | _] = tools, ref), do: ToolLookup.lookup(tools, ref)
  defp subject_lookup([], ref), do: ItemLookup.lookup([], ref)

  defp subject_key(%Item{} = item), do: ItemLookup.key(item)
  defp subject_key(%ToolEntry{} = tool), do: ToolLookup.key(tool)

  defp normalize_type(type) when type in [:action, :trigger], do: type
  defp normalize_type("action"), do: :action
  defp normalize_type("trigger"), do: :trigger
  defp normalize_type(type), do: type

  defp ranker_details(fun) when is_function(fun), do: %{ranker: :function}
  defp ranker_details(module) when is_atom(module), do: %{ranker: module, function: :rank}

  defp ranker_details({module, function}) when is_atom(module) and is_atom(function),
    do: %{ranker: module, function: function}

  defp ranker_details({module, function, extra_args}) when is_atom(module) and is_atom(function),
    do: %{ranker: module, function: function, arity: 2 + length(extra_args)}

  defp ranker_details(other), do: %{ranker: inspect(other)}
end
