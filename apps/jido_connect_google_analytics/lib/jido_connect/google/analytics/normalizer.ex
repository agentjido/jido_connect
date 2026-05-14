defmodule Jido.Connect.Google.Analytics.Normalizer do
  @moduledoc "Normalizes Google Analytics API payloads into stable package structs."

  alias Jido.Connect.Data
  alias Jido.Connect.Google.Analytics.{Dimension, Metric}

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

  defp normalize_items(items, normalizer) when is_list(items) do
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

  defp normalize_items(_items, _normalizer), do: {:error, :invalid_metadata_collection}
end
