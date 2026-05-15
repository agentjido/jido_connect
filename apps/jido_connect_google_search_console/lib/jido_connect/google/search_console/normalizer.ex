defmodule Jido.Connect.Google.SearchConsole.Normalizer do
  @moduledoc "Normalizes Google Search Console API payloads into stable package structs."

  alias Jido.Connect.Data
  alias Jido.Connect.Google.SearchConsole.{Row, SearchReport, Site}

  @doc "Normalizes a Search Console site entry payload."
  @spec site(map()) :: {:ok, Site.t()} | {:error, term()}
  def site(payload) when is_map(payload) do
    %{
      site_url: Data.get(payload, "siteUrl"),
      permission_level: Data.get(payload, "permissionLevel")
    }
    |> Data.compact()
    |> Site.new()
  end

  def site(_payload), do: {:error, :invalid_site_payload}

  @doc "Normalizes a Search Console search analytics query response payload."
  @spec search_report(map()) :: {:ok, SearchReport.t()} | {:error, term()}
  def search_report(payload) when is_map(payload) do
    rows =
      case Data.get(payload, "rows", []) do
        items when is_list(items) ->
          items
          |> Enum.map(&row/1)
          |> Enum.filter(fn
            {:ok, _} -> true
            _ -> false
          end)
          |> Enum.map(fn {:ok, row} -> row end)

        _ ->
          []
      end

    attrs =
      %{
        site_url: nil,
        rows: rows,
        response_aggregation_type: Data.get(payload, "responseAggregationType")
      }
      |> Data.compact()

    SearchReport.new(attrs)
  end

  def search_report(_payload), do: {:error, :invalid_search_report_payload}

  defp row(payload) when is_map(payload) do
    Row.new(%{
      keys: Data.get(payload, "keys", []),
      clicks: Data.get(payload, "clicks", 0),
      impressions: Data.get(payload, "impressions", 0),
      ctr: Data.get(payload, "ctr", 0.0),
      position: Data.get(payload, "position", 0.0)
    })
  end

  defp row(_payload), do: {:error, :invalid_row_payload}
end
