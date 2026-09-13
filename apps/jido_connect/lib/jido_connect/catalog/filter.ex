defmodule Jido.Connect.Catalog.Filter do
  @moduledoc false

  @spec entries([Jido.Connect.Catalog.Entry.t()], keyword()) :: [Jido.Connect.Catalog.Entry.t()]
  def entries(entries, opts) do
    entries
    |> filter_equal(:status, Keyword.get(opts, :status))
    |> filter_equal(:category, Keyword.get(opts, :category))
    |> filter_equal(:visibility, Keyword.get(opts, :visibility))
    |> filter_equal(:package, Keyword.get(opts, :package))
    |> filter_tag(Keyword.get(opts, :tag))
    |> filter_auth_kind(Keyword.get(opts, :auth_kind))
    |> filter_auth_profile(Keyword.get(opts, :auth_profile))
    |> filter_scope(Keyword.get(opts, :scope))
    |> filter_capability_kind(Keyword.get(opts, :capability_kind))
    |> filter_capability_feature(Keyword.get(opts, :capability, Keyword.get(opts, :feature)))
    |> filter_tool(Keyword.get(opts, :tool))
  end

  @spec tool_entries([Jido.Connect.Catalog.ToolEntry.t()], keyword()) :: [
          Jido.Connect.Catalog.ToolEntry.t()
        ]
  def tool_entries(tools, opts) do
    tools
    |> filter_tool_equal(:provider, Keyword.get(opts, :provider))
    |> filter_tool_equal(:type, Keyword.get(opts, :type))
    |> filter_tool_equal(:resource, Keyword.get(opts, :resource))
    |> filter_tool_equal(:verb, Keyword.get(opts, :verb))
    |> filter_tool_equal(:data_classification, Keyword.get(opts, :data_classification))
    |> filter_tool_equal(:risk, Keyword.get(opts, :risk))
    |> filter_tool_equal(:confirmation, Keyword.get(opts, :confirmation))
    |> filter_tool_tag(Keyword.get(opts, :tool_tag))
    |> filter_tool_auth_kind(Keyword.get(opts, :auth_kind))
    |> filter_tool_auth_profile(Keyword.get(opts, :auth_profile))
    |> filter_tool_scope(Keyword.get(opts, :scope))
    |> filter_tool_id(Keyword.get(opts, :tool))
  end

  @spec items([Jido.Connect.Catalog.Item.t()], keyword()) :: [Jido.Connect.Catalog.Item.t()]
  def items(items, opts) do
    items
    |> filter_tool_equal(:provider, Keyword.get(opts, :provider))
    |> filter_tool_equal(:type, Keyword.get(opts, :type))
    |> filter_tool_equal(:resource, Keyword.get(opts, :resource))
    |> filter_tool_equal(:verb, Keyword.get(opts, :verb))
    |> filter_tool_equal(:data_classification, Keyword.get(opts, :data_classification))
    |> filter_tool_equal(:risk, Keyword.get(opts, :risk))
    |> filter_tool_equal(:confirmation, Keyword.get(opts, :confirmation))
    |> filter_tool_tag(Keyword.get(opts, :tool_tag))
    |> filter_tool_auth_kind(Keyword.get(opts, :auth_kind))
    |> filter_tool_auth_profile(Keyword.get(opts, :auth_profile))
    |> filter_tool_scope(Keyword.get(opts, :scope))
    |> filter_tool_id(Keyword.get(opts, :tool))
  end

  defp filter_equal(entries, _field, value) when value in [nil, ""], do: entries

  defp filter_equal(entries, field, value) do
    value = normalize_filter_value(value)
    Enum.filter(entries, &(Map.fetch!(&1, field) == value))
  end

  defp filter_auth_kind(entries, kind) when kind in [nil, ""], do: entries

  defp filter_auth_kind(entries, kind) do
    kind = normalize_filter_value(kind)

    Enum.filter(entries, fn entry ->
      Enum.any?(entry.auth_profiles, &(&1.kind == kind))
    end)
  end

  defp filter_auth_profile(entries, profile) when profile in [nil, ""], do: entries

  defp filter_auth_profile(entries, profile) do
    profile = normalize_filter_value(profile)

    Enum.filter(entries, fn entry ->
      Enum.any?(entry.auth_profiles, &(&1.id == profile))
    end)
  end

  defp filter_scope(entries, scope) when scope in [nil, ""], do: entries

  defp filter_scope(entries, scope) do
    scope = to_string(scope)

    Enum.filter(entries, fn entry ->
      Enum.any?(entry.auth_profiles, &(scope in &1.scopes)) or
        Enum.any?(entry.actions, &(scope in &1.scopes)) or
        Enum.any?(entry.triggers, &(scope in &1.scopes))
    end)
  end

  defp filter_tag(entries, tag) when tag in [nil, ""], do: entries

  defp filter_tag(entries, tag) do
    tag = normalize_filter_value(tag)
    Enum.filter(entries, &(tag in &1.tags))
  end

  defp filter_capability_kind(entries, kind) when kind in [nil, ""], do: entries

  defp filter_capability_kind(entries, kind) do
    kind = normalize_filter_value(kind)

    Enum.filter(entries, fn entry ->
      Enum.any?(entry.capabilities, &(&1.kind == kind))
    end)
  end

  defp filter_capability_feature(entries, feature) when feature in [nil, ""], do: entries

  defp filter_capability_feature(entries, feature) do
    feature = normalize_filter_value(feature)

    Enum.filter(entries, fn entry ->
      Enum.any?(entry.capabilities, &(&1.feature == feature))
    end)
  end

  defp filter_tool(entries, tool) when tool in [nil, ""], do: entries

  defp filter_tool(entries, tool) do
    tool = to_string(tool)

    Enum.filter(entries, fn entry ->
      Enum.any?(entry.actions, &(&1.id == tool)) or Enum.any?(entry.triggers, &(&1.id == tool))
    end)
  end

  defp filter_tool_equal(tools, _field, value) when value in [nil, ""], do: tools

  defp filter_tool_equal(tools, field, value) do
    value = normalize_filter_value(value)
    Enum.filter(tools, &(Map.fetch!(&1, field) == value))
  end

  defp filter_tool_auth_kind(tools, kind) when kind in [nil, ""], do: tools

  defp filter_tool_auth_kind(tools, kind) do
    kind = normalize_filter_value(kind)
    Enum.filter(tools, &(kind in &1.auth_kinds))
  end

  defp filter_tool_auth_profile(tools, profile) when profile in [nil, ""], do: tools

  defp filter_tool_auth_profile(tools, profile) do
    profile = normalize_filter_value(profile)
    Enum.filter(tools, &(profile in &1.auth_profiles))
  end

  defp filter_tool_scope(tools, scope) when scope in [nil, ""], do: tools

  defp filter_tool_scope(tools, scope) do
    scope = to_string(scope)
    Enum.filter(tools, &(scope in &1.scopes))
  end

  defp filter_tool_id(tools, tool) when tool in [nil, ""], do: tools

  defp filter_tool_id(tools, tool) do
    tool = to_string(tool)
    Enum.filter(tools, &(&1.id == tool))
  end

  defp filter_tool_tag(tools, tag) when tag in [nil, ""], do: tools

  defp filter_tool_tag(tools, tag) do
    tag = normalize_filter_value(tag)
    Enum.filter(tools, &(tag in &1.tags))
  end

  defp normalize_filter_value(value) when is_atom(value), do: value

  defp normalize_filter_value(value) when is_binary(value) do
    String.to_existing_atom(value)
  rescue
    ArgumentError -> {:unknown, value}
  end
end
