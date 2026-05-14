defmodule Jido.Connect.Google.Analytics.Normalizer do
  @moduledoc "Normalizes Google Analytics API payloads into stable package structs."

  alias Jido.Connect.Data
  alias Jido.Connect.Google.Analytics.{Dimension, Metric, Report, Row}

  @doc "Normalizes a Google Analytics metadata payload."
  def metadata(payload) when is_map(payload) do
    with {:ok, dimensions} <- normalize_items(Data.get(payload, "dimensions", []), &dimension/1),
         {:ok, metrics} <- normalize_items(Data.get(payload, "metrics", []), &metric/1) do
      {:ok,
       %{
         metadata_name: Data.get(payload, "name"),
         dimensions: dimensions,
         metrics: metrics,
         comparisons: Data.get(payload, "comparisons", [])
       }
       |> Data.compact()}
    end
  end

  def metadata(_payload), do: {:error, :invalid_metadata_payload}

  @doc "Normalizes a Google Analytics runReport response payload."
  def report(payload) when is_map(payload) do
    metadata = Data.get(payload, "metadata", %{})

    with {:ok, dimension_headers} <-
           normalize_items(
             Data.get(payload, "dimensionHeaders", []),
             &dimension_header/1,
             :invalid_report_collection
           ),
         {:ok, metric_headers} <-
           normalize_items(
             Data.get(payload, "metricHeaders", []),
             &metric_header/1,
             :invalid_report_collection
           ),
         {:ok, rows} <-
           normalize_rows(Data.get(payload, "rows", []), dimension_headers, metric_headers),
         {:ok, totals} <-
           normalize_rows(Data.get(payload, "totals", []), dimension_headers, metric_headers),
         {:ok, maximums} <-
           normalize_rows(Data.get(payload, "maximums", []), dimension_headers, metric_headers),
         {:ok, minimums} <-
           normalize_rows(Data.get(payload, "minimums", []), dimension_headers, metric_headers) do
      %{
        property: Data.get(payload, "property"),
        dimension_headers: dimension_headers,
        metric_headers: metric_headers,
        rows: rows,
        totals: totals,
        maximums: maximums,
        minimums: minimums,
        row_count: Data.get(payload, "rowCount", 0),
        metadata: metadata,
        currency_code: Data.get(metadata, "currencyCode"),
        time_zone: Data.get(metadata, "timeZone"),
        property_quota: Data.get(payload, "propertyQuota", %{})
      }
      |> Data.compact()
      |> Report.new()
    end
  end

  def report(_payload), do: {:error, :invalid_report_payload}

  @doc "Normalizes a Google Analytics batchRunReports response payload."
  def batch_report(payload) when is_map(payload) do
    with {:ok, reports} <-
           normalize_items(
             Data.get(payload, "reports", []),
             &report/1,
             :invalid_report_collection
           ) do
      {:ok,
       %{
         reports: reports,
         kind: Data.get(payload, "kind")
       }
       |> Data.compact()}
    end
  end

  def batch_report(_payload), do: {:error, :invalid_report_payload}

  @doc "Normalizes a Google Analytics dimension metadata payload."
  def dimension(payload) when is_map(payload) do
    %{
      name: Data.get(payload, "apiName"),
      display_name: Data.get(payload, "uiName"),
      description: Data.get(payload, "description"),
      category: Data.get(payload, "category"),
      custom?: Data.get(payload, "customDefinition", false),
      deprecated_api_names: Data.get(payload, "deprecatedApiNames", [])
    }
    |> Data.compact()
    |> Dimension.new()
  end

  def dimension(_payload), do: {:error, :invalid_dimension_payload}

  @doc "Normalizes a Google Analytics metric metadata payload."
  def metric(payload) when is_map(payload) do
    %{
      name: Data.get(payload, "apiName"),
      display_name: Data.get(payload, "uiName"),
      description: Data.get(payload, "description"),
      category: Data.get(payload, "category"),
      type: Data.get(payload, "type"),
      expression: Data.get(payload, "expression"),
      custom?: Data.get(payload, "customDefinition", false),
      deprecated_api_names: Data.get(payload, "deprecatedApiNames", []),
      blocked_reasons: Data.get(payload, "blockedReasons", [])
    }
    |> Data.compact()
    |> Metric.new()
  end

  def metric(_payload), do: {:error, :invalid_metric_payload}

  defp dimension_header(payload) when is_map(payload) do
    %{
      name: Data.get(payload, "name")
    }
    |> Dimension.new()
  end

  defp dimension_header(_payload), do: {:error, :invalid_dimension_payload}

  defp metric_header(payload) when is_map(payload) do
    %{
      name: Data.get(payload, "name"),
      type: Data.get(payload, "type")
    }
    |> Data.compact()
    |> Metric.new()
  end

  defp metric_header(_payload), do: {:error, :invalid_metric_payload}

  defp normalize_rows(rows, dimension_headers, metric_headers) when is_list(rows) do
    rows
    |> Enum.reduce_while({:ok, []}, fn payload, {:ok, acc} ->
      case row(payload, dimension_headers, metric_headers) do
        {:ok, row} -> {:cont, {:ok, [row | acc]}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, rows} -> {:ok, Enum.reverse(rows)}
      {:error, error} -> {:error, error}
    end
  end

  defp normalize_rows(_rows, _dimension_headers, _metric_headers),
    do: {:error, :invalid_report_collection}

  defp row(payload, dimension_headers, metric_headers) when is_map(payload) do
    with {:ok, dimensions} <-
           row_dimensions(Data.get(payload, "dimensionValues", []), dimension_headers),
         {:ok, metrics} <- row_metrics(Data.get(payload, "metricValues", []), metric_headers) do
      %{
        dimensions: dimensions,
        metrics: metrics,
        metadata: Data.get(payload, "metadata", %{})
      }
      |> Row.new()
    end
  end

  defp row(_payload, _dimension_headers, _metric_headers), do: {:error, :invalid_report_row}

  defp row_dimensions(values, dimension_headers) when is_list(values) do
    values
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {payload, index}, {:ok, acc} ->
      case dimension_value(payload, Enum.at(dimension_headers, index), index) do
        {:ok, value} -> {:cont, {:ok, [value | acc]}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, values} -> {:ok, Enum.reverse(values)}
      {:error, error} -> {:error, error}
    end
  end

  defp row_dimensions(_values, _dimension_headers), do: {:error, :invalid_report_row}

  defp row_metrics(values, metric_headers) when is_list(values) do
    values
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {payload, index}, {:ok, acc} ->
      case metric_value(payload, Enum.at(metric_headers, index), index) do
        {:ok, value} -> {:cont, {:ok, [value | acc]}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, values} -> {:ok, Enum.reverse(values)}
      {:error, error} -> {:error, error}
    end
  end

  defp row_metrics(_values, _metric_headers), do: {:error, :invalid_report_row}

  defp dimension_value(payload, header, index) when is_map(payload) do
    %{
      name: header_name(header, "dimension_#{index + 1}"),
      value: Data.get(payload, "value")
    }
    |> Data.compact()
    |> Dimension.new()
  end

  defp dimension_value(_payload, _header, _index), do: {:error, :invalid_dimension_payload}

  defp metric_value(payload, header, index) when is_map(payload) do
    %{
      name: header_name(header, "metric_#{index + 1}"),
      value: Data.get(payload, "value"),
      type: header_type(header)
    }
    |> Data.compact()
    |> Metric.new()
  end

  defp metric_value(_payload, _header, _index), do: {:error, :invalid_metric_payload}

  defp header_name(%{name: name}, _fallback) when is_binary(name), do: name
  defp header_name(_header, fallback), do: fallback

  defp header_type(%{type: type}) when is_binary(type), do: type
  defp header_type(_header), do: nil

  defp normalize_items(items, normalizer, error \\ :invalid_metadata_collection)

  defp normalize_items(items, normalizer, _error) when is_list(items) do
    items
    |> Enum.reduce_while({:ok, []}, fn payload, {:ok, acc} ->
      case normalizer.(payload) do
        {:ok, item} -> {:cont, {:ok, [item | acc]}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, items} -> {:ok, Enum.reverse(items)}
      {:error, error} -> {:error, error}
    end
  end

  defp normalize_items(_items, _normalizer, error), do: {:error, error}
end
