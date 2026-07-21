defmodule Jido.Connect.Google.SearchConsole.Normalizer do
  @moduledoc "Normalizes Google Search Console API payloads into stable package structs."

  alias Jido.Connect.Data
  alias Jido.Connect.Google.SearchConsole.{Row, SearchReport, Sitemap, Site, URLInspection}

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

  @doc "Normalizes a Search Console sitemap entry payload."
  @spec sitemap(map()) :: {:ok, Sitemap.t()} | {:error, term()}
  def sitemap(payload) when is_map(payload) do
    attrs =
      %{
        path: Data.get(payload, "path"),
        last_submitted: Data.get(payload, "lastSubmitted"),
        is_pending: Data.get(payload, "isPending", false),
        last_downloaded: Data.get(payload, "lastDownloaded"),
        error_count: count_list(Data.get(payload, "errors", [])),
        warnings_count: count_list(Data.get(payload, "warnings", [])),
        type: Data.get(payload, "type"),
        contents: Data.get(payload, "contents", []),
        metadata: %{}
      }
      |> Data.compact()

    Sitemap.new(attrs)
  end

  def sitemap(_payload), do: {:error, :invalid_sitemap_payload}

  defp count_list(items) when is_list(items), do: length(items)
  defp count_list(_), do: 0

  @doc "Normalizes a Search Console URL inspection response payload."
  @spec url_inspection(map()) :: {:ok, URLInspection.t()} | {:error, term()}
  def url_inspection(payload) when is_map(payload) do
    result = Data.get(payload, "inspectionResult", %{})

    rich_results =
      case Data.get(result, "richResultsResult", %{}) |> Data.get("detectedItems", []) do
        items when is_list(items) -> items
        _ -> []
      end

    attrs =
      %{
        inspection_result_link: Data.get(result, "inspectionResultLink"),
        index_status: Data.get(result, "indexStatusResult", %{}),
        amp_result: Data.get(result, "ampResult", %{}),
        mobile_usability_result: Data.get(result, "mobileUsabilityResult", %{}),
        rich_results: rich_results,
        metadata: %{}
      }
      |> Data.compact()

    URLInspection.new(attrs)
  end

  def url_inspection(_payload), do: {:error, :invalid_url_inspection_payload}
end
