defmodule Jido.Connect.Catalog.Plugin do
  @moduledoc """
  First-class Jido plugin for catalog search, describe, and call.

  This is the canonical Jido runtime surface for Connect catalog operations.
  The plugin exposes only three stable actions and routes all execution through
  `Jido.Connect.Catalog.call_tool/3`.
  """

  alias Jido.Connect.Catalog.Actions.{CallTool, DescribeTool, SearchTools}

  @signal_routes [
    {"connect.catalog.search", SearchTools},
    {"connect.catalog.describe", DescribeTool},
    {"connect.catalog.call", CallTool}
  ]

  use Jido.Plugin,
    name: "jido_connect_catalog",
    state_key: :jido_connect_catalog,
    description: "Search, describe, and call Jido Connect catalog tools",
    category: "catalog",
    tags: ["jido_connect", "catalog", "tools"],
    capabilities: [:catalog_search, :catalog_describe, :catalog_call],
    singleton: true,
    actions: [SearchTools, DescribeTool, CallTool],
    signal_routes: @signal_routes,
    config_schema: Zoi.map()

  @impl Jido.Plugin
  def signal_routes(_config), do: @signal_routes

  @impl Jido.Plugin
  def handle_signal(_signal, _context), do: {:ok, :continue}
end
