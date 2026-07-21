defmodule Jido.Connect.Microsoft.Pagination do
  @moduledoc """
  Helpers for Microsoft Graph list APIs using OData pagination.

  Microsoft Graph list endpoints return results in OData envelopes:

      %{
        "@odata.context" => "...",
        "@odata.nextLink" => "https://graph.microsoft.com/v1.0/me/messages?$skip=25",
        "value" => [...]
      }

  This module provides helpers for:

  - Building `$top` / `$skip` query parameters.
  - Extracting `@odata.nextLink` and `@odata.deltaLink` from response bodies.
  - Extracting the `value` array from OData envelopes.
  - Building checkpoint metadata for durable pagination cursors.

  ## Usage

      # Build query params
      query = Pagination.query(%{q: "subject:test"}, page_size: 25)

      # Extract values from response
      {:ok, %{"value" => items}} = Transport.request(request, :get)
      values = Pagination.values(response_body)

      # Check for more pages
      has_more = Pagination.has_more?(response_body)
      next = Pagination.next_link(response_body)
  """

  alias Jido.Connect.Data

  @doc "Adds pagination options to a query map."
  @spec query(map(), keyword() | map()) :: map()
  def query(base \\ %{}, opts \\ %{}) when is_map(base) do
    opts = Map.new(opts)

    base
    |> maybe_put(:"$top", Map.get(opts, :page_size) || Map.get(opts, "page_size"))
    |> maybe_put(:"$skip", Map.get(opts, :skip) || Map.get(opts, "skip"))
  end

  @doc "Extracts the next page URL from a Microsoft Graph list response body."
  @spec next_link(map()) :: String.t() | nil
  def next_link(body) when is_map(body) do
    Data.get(body, "@odata.nextLink")
  end

  def next_link(_body), do: nil

  @doc "Extracts the delta link from a Microsoft Graph delta response body."
  @spec delta_link(map()) :: String.t() | nil
  def delta_link(body) when is_map(body) do
    Data.get(body, "@odata.deltaLink")
  end

  def delta_link(_body), do: nil

  @doc """
  Extracts the `value` array from a Microsoft Graph OData response body.

  Returns an empty list when the body is missing the `value` key or is not a
  map. Connector packages can use this to safely extract items without manual
  nil handling.
  """
  @spec values(map()) :: [map()]
  def values(body) when is_map(body) do
    case Data.get(body, "value") do
      items when is_list(items) -> items
      _missing_or_invalid -> []
    end
  end

  def values(_body), do: []

  @doc """
  Returns true when a Microsoft Graph response body contains a next page link.

  Connector packages can use this to decide whether to continue fetching pages
  or to treat the current page as the last.
  """
  @spec has_more?(map()) :: boolean()
  def has_more?(body) when is_map(body) do
    case Data.get(body, "@odata.nextLink") do
      link when is_binary(link) and link != "" -> true
      _no_link -> false
    end
  end

  def has_more?(_body), do: false

  @doc "Builds checkpoint metadata from a list response body."
  @spec checkpoint(map(), map()) :: map()
  def checkpoint(body, extra \\ %{}) when is_map(body) and is_map(extra) do
    %{
      next_link: next_link(body),
      delta_link: delta_link(body),
      value_count: length(values(body))
    }
    |> Map.merge(extra)
    |> Data.compact()
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, ""), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
