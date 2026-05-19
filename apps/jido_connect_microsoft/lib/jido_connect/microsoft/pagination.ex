defmodule Jido.Connect.Microsoft.Pagination do
  @moduledoc "Helpers for Microsoft Graph list APIs."

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

  @doc "Builds checkpoint metadata from a list response body."
  @spec checkpoint(map(), map()) :: map()
  def checkpoint(body, extra \\ %{}) when is_map(body) and is_map(extra) do
    %{
      next_link: next_link(body),
      delta_link: delta_link(body)
    }
    |> Map.merge(extra)
    |> Data.compact()
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, ""), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
