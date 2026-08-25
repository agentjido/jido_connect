defmodule Jido.Connect.Catalog.Search do
  @moduledoc false

  alias Jido.Connect.Catalog.{
    Entry,
    Item,
    ItemSearchResult,
    Tool,
    ToolEntry,
    ToolSearchResult
  }

  @spec entries([Entry.t()], String.t() | nil) :: [Entry.t()]
  def entries(entries, query) when query in [nil, ""], do: entries

  def entries(entries, query) when is_binary(query) do
    normalized_query = String.downcase(query)

    Enum.filter(entries, fn entry ->
      entry
      |> searchable_text()
      |> String.contains?(normalized_query)
    end)
  end

  @spec tools([ToolEntry.t()], String.t() | nil) :: [ToolEntry.t()]
  def tools(tools, query) when query in [nil, ""], do: tools

  def tools(tools, query) when is_binary(query) do
    normalized_query = String.downcase(query)

    Enum.filter(tools, fn tool ->
      tool
      |> tool_entry_search_text()
      |> String.contains?(normalized_query)
    end)
  end

  @spec items([Item.t()], String.t() | nil) :: [Item.t()]
  def items(items, query) when query in [nil, ""], do: items

  def items(items, query) when is_binary(query) do
    normalized_query = String.downcase(query)

    Enum.filter(items, fn item ->
      item
      |> item_search_text()
      |> String.contains?(normalized_query)
    end)
  end

  @spec ranked_tools([ToolEntry.t()], String.t() | nil) :: [ToolSearchResult.t()]
  def ranked_tools(tools, query) when query in [nil, ""] do
    tools
    |> Enum.map(&ToolSearchResult.new!(%{tool: &1, score: 0, matched_fields: []}))
    |> sort_ranked_results()
  end

  def ranked_tools(tools, query) when is_binary(query) do
    query = normalize(query)
    tokens = tokens(query)

    tools
    |> Enum.map(&rank_tool(&1, query, tokens))
    |> Enum.reject(&(&1.score <= 0))
    |> sort_ranked_results()
  end

  @spec ranked_items([Item.t()], String.t() | nil) :: [ItemSearchResult.t()]
  def ranked_items(items, query) when query in [nil, ""] do
    items
    |> Enum.map(&ItemSearchResult.new!(%{item: &1, score: 0, matched_fields: []}))
    |> sort_ranked_item_results()
  end

  def ranked_items(items, query) when is_binary(query) do
    query = normalize(query)
    tokens = tokens(query)

    items
    |> Enum.map(&rank_item(&1, query, tokens))
    |> Enum.reject(&(&1.score <= 0))
    |> sort_ranked_item_results()
  end

  defp searchable_text(%Entry{} = entry) do
    [
      entry.id,
      entry.name,
      entry.description,
      entry.category,
      entry.package,
      entry.version,
      entry.status,
      entry.tags,
      entry.visibility,
      inspect(entry.module),
      Enum.map(entry.docs, & &1),
      Enum.map(entry.capabilities, &[&1.kind, &1.feature, &1.label]),
      Enum.map(entry.policies, &[&1.id, &1.label, &1.description, &1.decision]),
      Enum.map(entry.schemas, &[&1.id, &1.label, &1.description]),
      Enum.map(
        entry.auth_profiles,
        &[
          &1.id,
          &1.kind,
          &1.label,
          &1.scopes,
          &1.default_scopes,
          &1.credential_fields,
          &1.lease_fields
        ]
      ),
      Enum.map(entry.actions, &tool_search_text/1),
      Enum.map(entry.triggers, &tool_search_text/1)
    ]
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
    |> Enum.map_join(" ", &to_string/1)
    |> String.downcase()
  end

  defp tool_search_text(%Tool{} = tool) do
    [
      tool.type,
      tool.id,
      tool.name,
      tool.label,
      tool.description,
      tool.tags,
      inspect(tool.module),
      tool.resource,
      tool.verb,
      tool.data_classification,
      tool.auth_profile,
      tool.auth_profiles,
      tool.policies,
      tool.scopes,
      tool.risk,
      tool.confirmation,
      tool.trigger_kind,
      tool.source
    ]
  end

  defp tool_entry_search_text(%ToolEntry{} = tool) do
    [
      tool.provider,
      tool.provider_name,
      tool.category,
      tool.package,
      tool.package_version,
      tool.type,
      tool.id,
      tool.name,
      tool.label,
      tool.description,
      tool.tags,
      inspect(tool.module),
      tool.resource,
      tool.verb,
      tool.data_classification,
      tool.auth_profile,
      tool.auth_profiles,
      tool.auth_kinds,
      tool.policies,
      tool.scopes,
      tool.risk,
      tool.confirmation,
      tool.trigger_kind,
      tool.source
    ]
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
    |> Enum.map_join(" ", &to_string/1)
    |> String.downcase()
  end

  defp item_search_text(%Item{} = item) do
    [
      item.ref,
      item.provider,
      item.provider_name,
      item.category,
      item.package,
      item.package_version,
      item.type,
      item.id,
      item.name,
      item.label,
      item.description,
      item.tags,
      inspect(item.module),
      item.resource,
      item.verb,
      item.data_classification,
      item.effect,
      item.availability,
      item.auth_profile,
      item.auth_profiles,
      item.auth_kinds,
      Enum.map(item.policies, & &1.id),
      item.scopes,
      item.risk,
      item.confirmation,
      item.trigger_kind,
      item.source
    ]
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
    |> Enum.map_join(" ", &to_string/1)
    |> String.downcase()
  end

  defp rank_tool(%ToolEntry{} = tool, query, tokens) do
    {score, matched_fields} =
      [
        {:id, [tool.id, "#{tool.provider}.#{tool.id}"], 1_000, 700, 550},
        {:name, [tool.name], 900, 650, 500},
        {:label, [tool.label], 800, 500, 400},
        {:resource, [tool.resource], 450, 350, 300},
        {:verb, [tool.verb], 450, 350, 300},
        {:provider, [tool.provider, tool.provider_name, tool.package], 300, 250, 200},
        {:package_version, [tool.package_version], 200, 150, 100},
        {:tags, [tool.tags], 500, 375, 300},
        {:description, [tool.description], 250, 175, 125},
        {:classification, [tool.data_classification], 200, 150, 125},
        {:auth, [tool.auth_profile, tool.auth_profiles, tool.auth_kinds], 175, 125, 100},
        {:scopes, [tool.scopes], 175, 125, 100},
        {:policies, [tool.policies], 150, 100, 75},
        {:risk, [tool.risk, tool.confirmation], 125, 100, 75},
        {:source, [tool.source], 100, 75, 50}
      ]
      |> Enum.reduce({0, []}, fn {field, values, exact, phrase, all_terms}, {score, fields} ->
        case match_score(values, query, tokens, exact, phrase, all_terms) do
          0 -> {score, fields}
          value -> {score + value, [field | fields]}
        end
      end)

    ToolSearchResult.new!(%{
      tool: tool,
      score: score,
      matched_fields: Enum.reverse(matched_fields)
    })
  end

  defp rank_item(%Item{} = item, query, tokens) do
    {score, matched_fields} =
      [
        {:ref, [item.ref], 1_100, 800, 600},
        {:id, [item.id, Item.legacy_ref(item)], 1_000, 700, 550},
        {:name, [item.name], 900, 650, 500},
        {:label, [item.label], 800, 500, 400},
        {:resource, [item.resource], 450, 350, 300},
        {:verb, [item.verb], 450, 350, 300},
        {:provider, [item.provider, item.provider_name, item.package], 300, 250, 200},
        {:package_version, [item.package_version], 200, 150, 100},
        {:tags, [item.tags], 500, 375, 300},
        {:description, [item.description], 250, 175, 125},
        {:classification, [item.data_classification], 200, 150, 125},
        {:auth, [item.auth_profile, item.auth_profiles, item.auth_kinds], 175, 125, 100},
        {:scopes, [item.scopes], 175, 125, 100},
        {:policies, [Enum.map(item.policies, & &1.id)], 150, 100, 75},
        {:risk, [item.risk, item.confirmation, item.effect], 125, 100, 75},
        {:availability, [item.availability], 100, 75, 50},
        {:source, [item.source], 100, 75, 50}
      ]
      |> Enum.reduce({0, []}, fn {field, values, exact, phrase, all_terms}, {score, fields} ->
        case match_score(values, query, tokens, exact, phrase, all_terms) do
          0 -> {score, fields}
          value -> {score + value, [field | fields]}
        end
      end)

    ItemSearchResult.new!(%{
      item: item,
      score: score,
      matched_fields: Enum.reverse(matched_fields)
    })
  end

  defp match_score(values, query, tokens, exact, phrase, all_terms) do
    values
    |> List.wrap()
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&normalize/1)
    |> Enum.reduce(0, fn value, score ->
      cond do
        value == query -> max(score, exact)
        String.contains?(value, query) -> max(score, phrase)
        tokens != [] and Enum.all?(tokens, &String.contains?(value, &1)) -> max(score, all_terms)
        true -> score
      end
    end)
  end

  defp sort_ranked_results(results) do
    Enum.sort_by(results, fn result ->
      {-result.score, to_string(result.tool.provider), result.tool.id}
    end)
  end

  defp sort_ranked_item_results(results) do
    Enum.sort_by(results, fn result ->
      {-result.score, to_string(result.item.provider), result.item.id,
       to_string(result.item.type)}
    end)
  end

  defp tokens(query) do
    query
    |> String.split(~r/\s+/, trim: true)
    |> Enum.uniq()
  end

  defp normalize(value) do
    value
    |> to_string()
    |> String.downcase()
    |> String.trim()
  end
end
