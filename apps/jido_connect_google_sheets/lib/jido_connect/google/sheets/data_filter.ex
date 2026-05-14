defmodule Jido.Connect.Google.Sheets.DataFilter do
  @moduledoc """
  Provider-specific Google Sheets DataFilter helpers.

  These helpers keep the filter contract in the Sheets package. They only
  normalize Google Sheets field names and validate the Google DataFilter union;
  they do not introduce a provider-agnostic query DSL.
  """

  @selector_keys [:developerMetadataLookup, :a1Range, :gridRange]
  @dimension_values ["ROWS", "COLUMNS"]

  @key_aliases %{
    "a1Range" => :a1Range,
    :a1_range => :a1Range,
    "a1_range" => :a1Range,
    "gridRange" => :gridRange,
    :grid_range => :gridRange,
    "grid_range" => :gridRange,
    "developerMetadataLookup" => :developerMetadataLookup,
    :developer_metadata_lookup => :developerMetadataLookup,
    "developer_metadata_lookup" => :developerMetadataLookup,
    "locationType" => :locationType,
    :location_type => :locationType,
    "location_type" => :locationType,
    "metadataLocation" => :metadataLocation,
    :metadata_location => :metadataLocation,
    "metadata_location" => :metadataLocation,
    "locationMatchingStrategy" => :locationMatchingStrategy,
    :location_matching_strategy => :locationMatchingStrategy,
    "location_matching_strategy" => :locationMatchingStrategy,
    "metadataId" => :metadataId,
    :metadata_id => :metadataId,
    "metadata_id" => :metadataId,
    "metadataKey" => :metadataKey,
    :metadata_key => :metadataKey,
    "metadata_key" => :metadataKey,
    "metadataValue" => :metadataValue,
    :metadata_value => :metadataValue,
    "metadata_value" => :metadataValue,
    "sheetId" => :sheetId,
    :sheet_id => :sheetId,
    "sheet_id" => :sheetId,
    "dimensionRange" => :dimensionRange,
    :dimension_range => :dimensionRange,
    "dimension_range" => :dimensionRange,
    "startIndex" => :startIndex,
    :start_index => :startIndex,
    "start_index" => :startIndex,
    "endIndex" => :endIndex,
    :end_index => :endIndex,
    "end_index" => :endIndex,
    "dataFilter" => :dataFilter,
    :data_filter => :dataFilter,
    "data_filter" => :dataFilter,
    "majorDimension" => :majorDimension,
    :major_dimension => :majorDimension,
    "major_dimension" => :majorDimension
  }

  @doc "Returns true when a list contains one or more valid Google DataFilter maps."
  def valid_filters?(filters) when is_list(filters) and filters != [] do
    Enum.all?(filters, &valid_filter?/1)
  end

  def valid_filters?(_filters), do: false

  @doc "Returns true when a map is a valid Google DataFilter union."
  def valid_filter?(filter) when is_map(filter) do
    filter
    |> to_google_filter()
    |> valid_normalized_filter?()
  end

  def valid_filter?(_filter), do: false

  @doc "Normalizes a list of Google DataFilter maps to Google JSON field names."
  def to_google_filters(filters) when is_list(filters), do: Enum.map(filters, &to_google_filter/1)

  @doc "Normalizes one Google DataFilter map to Google JSON field names."
  def to_google_filter(filter) when is_map(filter), do: normalize_map(filter)

  @doc "Normalizes one DataFilterValueRange input map for values APIs."
  def to_google_value_range(entry) when is_map(entry) do
    %{
      dataFilter: entry |> data_filter_from_entry() |> to_google_filter(),
      majorDimension: entry |> get_value(:majorDimension) |> default_major_dimension(),
      values: get_value(entry, :values, [])
    }
  end

  @doc "Returns true when a DataFilterValueRange input has the provider-required shape."
  def valid_value_range?(entry) when is_map(entry) do
    data_filter = data_filter_from_entry(entry)
    values = get_value(entry, :values)
    major_dimension = get_value(entry, :majorDimension)

    valid_filter?(data_filter) and is_list(values) and
      (is_nil(major_dimension) or major_dimension in @dimension_values)
  end

  def valid_value_range?(_entry), do: false

  defp data_filter_from_entry(entry), do: get_value(entry, :dataFilter, %{})

  defp valid_normalized_filter?(filter) do
    selectors = Enum.filter(@selector_keys, &Map.has_key?(filter, &1))

    case selectors do
      [selector] -> valid_selector?(selector, Map.get(filter, selector))
      _other -> false
    end
  end

  defp valid_selector?(:a1Range, value), do: is_binary(value) and String.trim(value) != ""
  defp valid_selector?(:gridRange, value), do: is_map(value) and map_size(value) > 0

  defp valid_selector?(:developerMetadataLookup, value),
    do: is_map(value) and map_size(value) > 0

  defp default_major_dimension(nil), do: "ROWS"
  defp default_major_dimension(value), do: value

  defp normalize_map(map) do
    map
    |> Enum.map(fn {key, value} -> {google_key(key), normalize_value(value)} end)
    |> Map.new()
  end

  defp normalize_value(value) when is_map(value), do: normalize_map(value)
  defp normalize_value(value) when is_list(value), do: Enum.map(value, &normalize_value/1)
  defp normalize_value(value), do: value

  defp google_key(key), do: Map.get(@key_aliases, key, key)

  defp get_value(map, key, default \\ nil) do
    alias_keys =
      @key_aliases
      |> Enum.filter(fn {_candidate, canonical} -> canonical == key end)
      |> Enum.map(fn {candidate, _canonical} -> candidate end)

    [key | alias_keys]
    |> Enum.reduce_while(default, fn candidate, acc ->
      if Map.has_key?(map, candidate) do
        {:halt, Map.get(map, candidate)}
      else
        {:cont, acc}
      end
    end)
  end
end
