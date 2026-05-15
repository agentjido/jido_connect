defmodule Jido.Connect.Google.SearchConsole.Handlers.Actions.QuerySearchAnalytics do
  @moduledoc false

  alias Jido.Connect.{Data, Error}
  alias Jido.Connect.Google.SearchConsole.Handlers.Actions.ResourceHelpers

  @reason :invalid_search_analytics_query

  @valid_dimensions MapSet.new([
                      "query",
                      "page",
                      "country",
                      "device",
                      "searchAppearance",
                      "search_appearance"
                    ])

  @valid_search_types MapSet.new([
                        "web",
                        "image",
                        "video",
                        "news",
                        "discover",
                        "googleNews",
                        "google_news"
                      ])

  @valid_aggregation_types MapSet.new(["auto", "byProperty", "byPage", "by_news_property"])
  @valid_data_states MapSet.new(["all", "final"])
  @min_row_limit 1
  @max_row_limit 25_000
  @min_start_row 0
  @max_dimensions 3

  def run(input, %{credentials: credentials}) do
    with {:ok, site_url} <- validate_site_url(input),
         {:ok, start_date} <- validate_date(input, :start_date),
         {:ok, end_date} <- validate_date(input, :end_date),
         {:ok, dimensions} <- validate_dimensions(input),
         {:ok, search_type} <- validate_search_type(input),
         {:ok, dimension_filter_groups} <- validate_dimension_filter_groups(input),
         {:ok, row_limit} <- validate_row_limit(input),
         {:ok, start_row} <- validate_start_row(input),
         {:ok, aggregation_type} <-
           validate_enum(input, :aggregation_type, @valid_aggregation_types),
         {:ok, data_state} <- validate_enum(input, :data_state, @valid_data_states),
         {:ok, client} <- ResourceHelpers.fetch_client(credentials),
         params <-
           build_params(
             site_url,
             start_date,
             end_date,
             dimensions,
             search_type,
             dimension_filter_groups,
             row_limit,
             start_row,
             aggregation_type,
             data_state
           ),
         {:ok, report} <-
           client.query_search_analytics(params, Map.get(credentials, :access_token)) do
      {:ok, %{report: ResourceHelpers.public_map(report)}}
    end
  end

  defp validate_site_url(input) do
    case Data.get(input, :site_url) do
      value when is_binary(value) ->
        trimmed = String.trim(value)

        if trimmed == "" do
          validation_error("site_url must be a non-empty URL or domain property",
            field: :site_url
          )
        else
          {:ok, trimmed}
        end

      _missing ->
        validation_error("site_url is required",
          field: :site_url
        )
    end
  end

  defp validate_date(input, field) do
    case Data.get(input, field) do
      value when is_binary(value) ->
        trimmed = String.trim(value)

        if valid_date?(trimmed) do
          {:ok, trimmed}
        else
          validation_error("#{field} must be a valid date in YYYY-MM-DD format",
            field: field,
            value: value
          )
        end

      _missing ->
        validation_error("#{field} is required",
          field: field
        )
    end
  end

  defp valid_date?(value) do
    case Date.from_iso8601(value) do
      {:ok, _date} -> true
      {:error, _} -> false
    end
  end

  defp validate_dimensions(input) do
    case Data.get(input, :dimensions, []) do
      values when is_list(values) ->
        cond do
          length(values) > @max_dimensions ->
            validation_error("dimensions must have at most #{@max_dimensions} entries",
              field: :dimensions,
              count: length(values),
              max_count: @max_dimensions
            )

          true ->
            normalize_dimensions(values)
        end

      _invalid ->
        validation_error("dimensions must be a list",
          field: :dimensions
        )
    end
  end

  defp normalize_dimensions(values) do
    values
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {value, index}, {:ok, acc} ->
      case validate_single_dimension(value, index) do
        {:ok, dim} -> {:cont, {:ok, [dim | acc]}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, dims} -> {:ok, Enum.reverse(dims)}
      {:error, error} -> {:error, error}
    end
  end

  defp validate_single_dimension(value, index) when is_binary(value) do
    trimmed = String.trim(value)

    cond do
      trimmed == "" ->
        validation_error("dimension at index #{index} must be a non-empty string",
          field: :dimensions,
          index: index
        )

      MapSet.member?(@valid_dimensions, trimmed) ->
        {:ok, normalize_dimension(trimmed)}

      true ->
        validation_error("dimension at index #{index} is not a valid dimension",
          field: :dimensions,
          index: index,
          value: value,
          valid_values: MapSet.to_list(@valid_dimensions)
        )
    end
  end

  defp validate_single_dimension(value, index) do
    validation_error("dimension at index #{index} must be a string",
      field: :dimensions,
      index: index,
      value: value
    )
  end

  defp normalize_dimension("search_appearance"), do: "searchAppearance"
  defp normalize_dimension("google_news"), do: "googleNews"
  defp normalize_dimension(other), do: other

  defp validate_search_type(input) do
    case Data.get(input, :search_type) do
      nil ->
        {:ok, "web"}

      value when is_binary(value) ->
        trimmed = String.trim(value)

        if MapSet.member?(@valid_search_types, trimmed) do
          {:ok, normalize_dimension(trimmed)}
        else
          validation_error("search_type is not valid",
            field: :search_type,
            value: value,
            valid_values: MapSet.to_list(@valid_search_types)
          )
        end

      value ->
        validation_error("search_type must be a string",
          field: :search_type,
          value: value
        )
    end
  end

  defp validate_dimension_filter_groups(input) do
    case Data.get(input, :dimension_filter_groups, []) do
      values when is_list(values) ->
        values
        |> Enum.with_index()
        |> Enum.reduce_while({:ok, []}, fn {value, index}, {:ok, acc} ->
          case validate_filter_group(value, index) do
            {:ok, group} -> {:cont, {:ok, [group | acc]}}
            {:error, error} -> {:halt, {:error, error}}
          end
        end)
        |> case do
          {:ok, groups} -> {:ok, Enum.reverse(groups)}
          {:error, error} -> {:error, error}
        end

      value ->
        validation_error("dimension_filter_groups must be a list",
          field: :dimension_filter_groups,
          value: value
        )
    end
  end

  defp validate_filter_group(group, _index) when is_map(group), do: {:ok, group}

  defp validate_filter_group(value, index) do
    validation_error("dimension_filter_groups entry at index #{index} must be a map",
      field: :dimension_filter_groups,
      index: index,
      value: value
    )
  end

  defp validate_row_limit(input) do
    case Data.get(input, :row_limit) do
      nil ->
        {:ok, 1000}

      value ->
        case parse_integer(value) do
          {:ok, integer} when integer >= @min_row_limit and integer <= @max_row_limit ->
            {:ok, integer}

          {:ok, _out_of_range} ->
            validation_error("row_limit must be between #{@min_row_limit} and #{@max_row_limit}",
              field: :row_limit,
              value: value,
              min: @min_row_limit,
              max: @max_row_limit
            )

          :error ->
            validation_error("row_limit must be an integer",
              field: :row_limit,
              value: value
            )
        end
    end
  end

  defp validate_start_row(input) do
    case Data.get(input, :start_row) do
      nil ->
        {:ok, 0}

      value ->
        case parse_integer(value) do
          {:ok, integer} when integer >= @min_start_row ->
            {:ok, integer}

          {:ok, _out_of_range} ->
            validation_error("start_row must be >= #{@min_start_row}",
              field: :start_row,
              value: value,
              min: @min_start_row
            )

          :error ->
            validation_error("start_row must be an integer",
              field: :start_row,
              value: value
            )
        end
    end
  end

  defp validate_enum(input, field, valid_set) do
    case Data.get(input, field) do
      nil ->
        {:ok, nil}

      value when is_binary(value) ->
        trimmed = String.trim(value)

        if MapSet.member?(valid_set, trimmed) do
          {:ok, trimmed}
        else
          validation_error("#{field} is not a valid value",
            field: field,
            value: value,
            valid_values: MapSet.to_list(valid_set)
          )
        end

      value ->
        validation_error("#{field} must be a string",
          field: field,
          value: value
        )
    end
  end

  defp parse_integer(value) when is_integer(value), do: {:ok, value}

  defp parse_integer(value) when is_binary(value) do
    case value |> String.trim() |> Integer.parse() do
      {integer, ""} -> {:ok, integer}
      _invalid -> :error
    end
  end

  defp parse_integer(_value), do: :error

  defp build_params(
         site_url,
         start_date,
         end_date,
         dimensions,
         search_type,
         dimension_filter_groups,
         row_limit,
         start_row,
         aggregation_type,
         data_state
       ) do
    %{
      site_url: site_url,
      body:
        %{}
        |> Map.put("startDate", start_date)
        |> Map.put("endDate", end_date)
        |> put_list("dimensions", dimensions)
        |> Map.put("type", search_type)
        |> put_list("dimensionFilterGroups", dimension_filter_groups)
        |> Map.put("rowLimit", row_limit)
        |> Map.put("startRow", start_row)
        |> put_string("aggregationType", aggregation_type)
        |> put_string("dataState", data_state)
    }
  end

  defp put_list(map, _key, []), do: map
  defp put_list(map, key, value), do: Map.put(map, key, value)

  defp put_string(map, _key, nil), do: map
  defp put_string(map, key, value), do: Map.put(map, key, value)

  defp validation_error(message, opts) do
    field = Keyword.get(opts, :field)
    value = Keyword.get(opts, :value)

    details =
      %{field: field}
      |> maybe_put(:value, value)
      |> Map.merge(
        opts
        |> Keyword.drop([:field, :value])
        |> Map.new()
      )
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    {:error, Error.validation(message, reason: @reason, details: details)}
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
