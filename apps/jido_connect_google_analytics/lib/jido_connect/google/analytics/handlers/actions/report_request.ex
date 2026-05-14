defmodule Jido.Connect.Google.Analytics.Handlers.Actions.ReportRequest do
  @moduledoc false

  alias Jido.Connect.{Data, Error}
  alias Jido.Connect.Google.Analytics.Handlers.Actions.ResourceHelpers

  @max_batch_requests 5
  @max_dimensions 9
  @max_metrics 10
  @max_limit 250_000

  @date_pattern ~r/^\d{4}-\d{2}-\d{2}$/
  @relative_date_pattern ~r/^\d+daysAgo$/

  def run_report_input(input) do
    with {:ok, property} <- ResourceHelpers.normalize_property(Data.get(input, :property)),
         {:ok, body} <- report_body(input) do
      {:ok, %{property: property, body: body}}
    end
  end

  def batch_run_reports_input(input) do
    with {:ok, property} <- ResourceHelpers.normalize_property(Data.get(input, :property)),
         {:ok, requests} <- batch_requests(input, property) do
      {:ok, %{property: property, body: %{"requests" => requests}}}
    end
  end

  defp batch_requests(input, property) do
    case Data.get(input, :requests) do
      requests when is_list(requests) and requests != [] ->
        cond do
          length(requests) > @max_batch_requests ->
            validation_error("Google Analytics batch report request count exceeds limit",
              reason: :invalid_report_request,
              field: :requests,
              max_requests: @max_batch_requests,
              request_count: length(requests)
            )

          true ->
            normalize_batch_requests(requests, property)
        end

      _invalid ->
        validation_error("Google Analytics batch report requires non-empty requests",
          reason: :invalid_report_request,
          field: :requests,
          expected: "non-empty list"
        )
    end
  end

  defp normalize_batch_requests(requests, property) do
    requests
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {request, index}, {:ok, acc} ->
      with :ok <- validate_batch_request_shape(request, index),
           :ok <- validate_batch_request_property(request, property, index),
           {:ok, body} <- report_body(request) do
        {:cont, {:ok, [body | acc]}}
      else
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, requests} -> {:ok, Enum.reverse(requests)}
      {:error, error} -> {:error, error}
    end
  end

  defp validate_batch_request_shape(request, _index) when is_map(request), do: :ok

  defp validate_batch_request_shape(_request, index) do
    validation_error("Google Analytics batch report request must be a map",
      reason: :invalid_report_request,
      field: :requests,
      index: index
    )
  end

  defp validate_batch_request_property(request, property, index) do
    case Data.get(request, :property) do
      nil ->
        :ok

      value ->
        case ResourceHelpers.normalize_property(value) do
          {:ok, ^property} ->
            :ok

          {:ok, nested_property} ->
            validation_error(
              "Google Analytics batch report request property must match batch property",
              reason: :invalid_report_request,
              field: :property,
              index: index,
              expected: property,
              value: nested_property
            )

          {:error, error} ->
            {:error, error}
        end
    end
  end

  defp report_body(input) do
    with {:ok, date_ranges} <- date_ranges(input),
         {:ok, dimensions} <-
           named_collection(input, :dimensions, @max_dimensions, required?: false),
         {:ok, metrics} <- named_collection(input, :metrics, @max_metrics, required?: true),
         {:ok, dimension_filter} <- optional_map(input, :dimension_filter),
         {:ok, metric_filter} <- optional_map(input, :metric_filter),
         {:ok, order_bys} <- optional_map_list(input, :order_bys),
         {:ok, metric_aggregations} <- optional_string_list(input, :metric_aggregations),
         {:ok, comparisons} <- optional_map_list(input, :comparisons),
         {:ok, cohort_spec} <- optional_map(input, :cohort_spec),
         {:ok, limit} <- optional_integer_string(input, :limit, min: 1, max: @max_limit),
         {:ok, offset} <- optional_integer_string(input, :offset, min: 0),
         {:ok, currency_code} <- optional_string(input, :currency_code),
         {:ok, keep_empty_rows} <- optional_boolean(input, :keep_empty_rows),
         {:ok, return_property_quota} <- optional_boolean(input, :return_property_quota) do
      {:ok,
       %{}
       |> put_present("dateRanges", date_ranges)
       |> put_not_empty("dimensions", dimensions)
       |> put_present("metrics", metrics)
       |> put_present("dimensionFilter", dimension_filter)
       |> put_present("metricFilter", metric_filter)
       |> put_not_empty("orderBys", order_bys)
       |> put_not_empty("metricAggregations", metric_aggregations)
       |> put_not_empty("comparisons", comparisons)
       |> put_present("cohortSpec", cohort_spec)
       |> put_present("limit", limit)
       |> put_present("offset", offset)
       |> put_present("currencyCode", currency_code)
       |> put_present("keepEmptyRows", keep_empty_rows)
       |> put_present("returnPropertyQuota", return_property_quota)}
    end
  end

  defp date_ranges(input) do
    case Data.get(input, :date_ranges) do
      ranges when is_list(ranges) and ranges != [] ->
        ranges
        |> Enum.with_index()
        |> Enum.reduce_while({:ok, []}, fn {range, index}, {:ok, acc} ->
          case date_range(range, index) do
            {:ok, range} -> {:cont, {:ok, [range | acc]}}
            {:error, error} -> {:halt, {:error, error}}
          end
        end)
        |> case do
          {:ok, ranges} -> {:ok, Enum.reverse(ranges)}
          {:error, error} -> {:error, error}
        end

      _invalid ->
        validation_error("Google Analytics report requires non-empty date_ranges",
          reason: :invalid_report_request,
          field: :date_ranges,
          expected: "non-empty list"
        )
    end
  end

  defp date_range(range, index) when is_map(range) do
    with {:ok, start_date} <- date_value(range, :start_date, index),
         {:ok, end_date} <- date_value(range, :end_date, index),
         {:ok, name} <- optional_string(range, :name) do
      {:ok,
       %{}
       |> put_present("startDate", start_date)
       |> put_present("endDate", end_date)
       |> put_present("name", name)}
    end
  end

  defp date_range(_range, index) do
    validation_error("Google Analytics report date range must be a map",
      reason: :invalid_report_request,
      field: :date_ranges,
      index: index
    )
  end

  defp date_value(range, field, index) do
    case get_any(range, date_keys(field)) do
      value when is_binary(value) ->
        value = String.trim(value)

        if valid_date_value?(value) do
          {:ok, value}
        else
          invalid_date(field, value, index)
        end

      value ->
        invalid_date(field, value, index)
    end
  end

  defp date_keys(:start_date), do: [:start_date, "start_date", :startDate, "startDate"]
  defp date_keys(:end_date), do: [:end_date, "end_date", :endDate, "endDate"]

  defp valid_date_value?("today"), do: true
  defp valid_date_value?("yesterday"), do: true

  defp valid_date_value?(value) do
    Regex.match?(@date_pattern, value) or Regex.match?(@relative_date_pattern, value)
  end

  defp invalid_date(field, value, index) do
    validation_error(
      "Google Analytics report date ranges require valid start_date and end_date values",
      reason: :invalid_report_request,
      field: field,
      index: index,
      value: value,
      expected: "YYYY-MM-DD, today, yesterday, or NdaysAgo"
    )
  end

  defp named_collection(input, field, max_count, opts) do
    required? = Keyword.fetch!(opts, :required?)

    case Data.get(input, field, []) do
      values when is_list(values) ->
        cond do
          values == [] and required? ->
            invalid_named_collection(field, %{expected: "non-empty list"})

          length(values) > max_count ->
            invalid_named_collection(field, %{max_count: max_count, count: length(values)})

          true ->
            normalize_named_collection(values, field)
        end

      _invalid ->
        invalid_named_collection(field, %{expected: :list})
    end
  end

  defp normalize_named_collection(values, field) do
    values
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {value, index}, {:ok, acc} ->
      case named_entry(value, field, index) do
        {:ok, entry} -> {:cont, {:ok, [entry | acc]}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, values} -> {:ok, Enum.reverse(values)}
      {:error, error} -> {:error, error}
    end
  end

  defp named_entry(value, field, index) when is_binary(value) do
    case String.trim(value) do
      "" -> invalid_named_entry(field, index, value)
      name -> {:ok, %{"name" => name}}
    end
  end

  defp named_entry(value, field, index) when is_map(value) do
    case get_any(value, [:name, "name"]) do
      name when is_binary(name) ->
        case String.trim(name) do
          "" -> invalid_named_entry(field, index, name)
          name -> {:ok, value |> google_shape() |> Map.put("name", name)}
        end

      _missing ->
        invalid_named_entry(field, index, value)
    end
  end

  defp named_entry(value, field, index), do: invalid_named_entry(field, index, value)

  defp invalid_named_entry(field, index, value) do
    validation_error("Google Analytics report #{field} entries must have non-empty names",
      reason: :invalid_report_request,
      field: field,
      index: index,
      value: value
    )
  end

  defp invalid_named_collection(field, details) do
    validation_error("Google Analytics report #{field} are invalid",
      reason: :invalid_report_request,
      field: field,
      details: details
    )
  end

  defp optional_map(input, field) do
    case Data.get(input, field) do
      nil ->
        {:ok, nil}

      value when is_map(value) ->
        {:ok, google_shape(value)}

      value ->
        validation_error("Google Analytics report #{field} must be a map",
          reason: :invalid_report_request,
          field: field,
          value: value
        )
    end
  end

  defp optional_map_list(input, field) do
    case Data.get(input, field, []) do
      values when is_list(values) ->
        values
        |> Enum.with_index()
        |> Enum.reduce_while({:ok, []}, fn {value, index}, {:ok, acc} ->
          if is_map(value) do
            {:cont, {:ok, [google_shape(value) | acc]}}
          else
            {:halt,
             validation_error("Google Analytics report #{field} entries must be maps",
               reason: :invalid_report_request,
               field: field,
               index: index,
               value: value
             )}
          end
        end)
        |> case do
          {:ok, values} -> {:ok, Enum.reverse(values)}
          {:error, error} -> {:error, error}
        end

      value ->
        validation_error("Google Analytics report #{field} must be a list",
          reason: :invalid_report_request,
          field: field,
          value: value
        )
    end
  end

  defp optional_string_list(input, field) do
    case Data.get(input, field, []) do
      values when is_list(values) ->
        values
        |> Enum.with_index()
        |> Enum.reduce_while({:ok, []}, fn {value, index}, {:ok, acc} ->
          case trim_non_empty_string(value) do
            {:ok, value} ->
              {:cont, {:ok, [value | acc]}}

            :error ->
              {:halt,
               validation_error(
                 "Google Analytics report #{field} entries must be non-empty strings",
                 reason: :invalid_report_request,
                 field: field,
                 index: index,
                 value: value
               )}
          end
        end)
        |> case do
          {:ok, values} -> {:ok, Enum.reverse(values)}
          {:error, error} -> {:error, error}
        end

      value ->
        validation_error("Google Analytics report #{field} must be a list",
          reason: :invalid_report_request,
          field: field,
          value: value
        )
    end
  end

  defp optional_integer_string(input, field, opts) do
    case Data.get(input, field) do
      nil ->
        {:ok, nil}

      value ->
        min = Keyword.fetch!(opts, :min)
        max = Keyword.get(opts, :max)

        case parse_integer(value) do
          {:ok, integer} ->
            with :ok <- validate_integer_range(integer, field, min, max, value) do
              {:ok, Integer.to_string(integer)}
            end

          :error ->
            validation_error("Google Analytics report #{field} must be an integer",
              reason: :invalid_report_request,
              field: field,
              value: value
            )
        end
    end
  end

  defp optional_string(input, field) do
    case Data.get(input, field) do
      nil ->
        {:ok, nil}

      value ->
        case trim_non_empty_string(value) do
          {:ok, value} -> {:ok, value}
          :error -> {:ok, nil}
        end
    end
  end

  defp optional_boolean(input, field) do
    case Data.get(input, field) do
      nil ->
        {:ok, nil}

      value when is_boolean(value) ->
        {:ok, value}

      value ->
        validation_error("Google Analytics report #{field} must be a boolean",
          reason: :invalid_report_request,
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

  defp validate_integer_range(integer, _field, min, nil, _original) when integer >= min, do: :ok

  defp validate_integer_range(integer, _field, min, max, _original)
       when integer >= min and integer <= max,
       do: :ok

  defp validate_integer_range(_integer, field, min, max, original) do
    validation_error("Google Analytics report #{field} is outside the supported range",
      reason: :invalid_report_request,
      field: field,
      value: original,
      min: min,
      max: max
    )
  end

  defp trim_non_empty_string(value) when is_binary(value) do
    case String.trim(value) do
      "" -> :error
      value -> {:ok, value}
    end
  end

  defp trim_non_empty_string(_value), do: :error

  defp google_shape(value) when is_list(value), do: Enum.map(value, &google_shape/1)

  defp google_shape(value) when is_map(value) do
    value
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new(fn {key, value} -> {google_key(key), google_shape(value)} end)
  end

  defp google_shape(value), do: value

  defp google_key(key) when is_atom(key), do: key |> Atom.to_string() |> google_key()

  defp google_key(key) when is_binary(key) do
    case String.split(key, "_") do
      [single] -> single
      [first | rest] -> first <> Enum.map_join(rest, &Macro.camelize/1)
    end
  end

  defp google_key(key), do: key

  defp get_any(map, keys, default \\ nil) do
    Enum.find_value(keys, default, fn key ->
      case Data.get(map, key, :__missing__) do
        :__missing__ -> nil
        value -> value
      end
    end)
  end

  defp put_present(map, _key, nil), do: map
  defp put_present(map, key, value), do: Map.put(map, key, value)

  defp put_not_empty(map, _key, []), do: map
  defp put_not_empty(map, key, value), do: put_present(map, key, value)

  defp validation_error(message, opts) do
    {reason, details} = Keyword.pop!(opts, :reason)

    details =
      details
      |> Keyword.delete(:details)
      |> Map.new()
      |> Map.merge(Map.new(Keyword.get(details, :details, %{})))

    {:error, Error.validation(message, reason: reason, details: details)}
  end
end
