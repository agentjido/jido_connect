defmodule Jido.Connect.Catalog.Actions.SearchTools do
  @moduledoc "Search installed Jido Connect catalog tools."

  use Jido.Action,
    name: "connect_catalog_search",
    description: "Search Jido Connect catalog tools",
    schema:
      Zoi.object(
        %{
          query: Zoi.string() |> Zoi.optional(),
          filters: Zoi.map() |> Zoi.optional(),
          limit: Zoi.integer() |> Zoi.min(0) |> Zoi.optional(),
          pack: Zoi.any() |> Zoi.optional()
        },
        coerce: true
      ),
    output_schema: Zoi.object(%{results: Zoi.list(Zoi.any())})

  alias Jido.Connect.Catalog
  alias Jido.Connect.Catalog.Input

  @impl true
  def run(params, context) do
    with {:ok, query, opts, limit} <- Input.search_params(params, context),
         results when is_list(results) <- Catalog.search_tools(query, opts) do
      {:ok, %{results: results |> limit_results(limit) |> Enum.map(&Catalog.to_map/1)}}
    else
      {:error, error} -> {:error, error}
    end
  end

  defp limit_results(results, limit) when is_integer(limit), do: Enum.take(results, limit)
  defp limit_results(results, _limit), do: results
end
