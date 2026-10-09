defmodule Jido.Connect.Catalog.Plugin do
  @moduledoc """
  Jido v3 Plugin for catalog search, describe, and call configuration.

  Exposes three Action modules and route suggestions. The host declares its
  Agent routes and passes Connect context to each invocation. Registering this
  module as a v3 Plugin does not install routes or inject credentials.
  """

  alias Jido.Connect.Catalog.Actions.{CallTool, DescribeTool, SearchTools}
  alias Jido.Agent.Plugin.Preparation

  @signal_routes [
    {"connect.catalog.search", SearchTools},
    {"connect.catalog.describe", DescribeTool},
    {"connect.catalog.call", CallTool}
  ]

  use Jido.Plugin

  @catalog_signal_types Enum.map(@signal_routes, &elem(&1, 0))

  @impl Jido.Plugin
  def prepare(%Preparation{signal: %{type: type}}, opts)
      when type in @catalog_signal_types do
    {:ok, Map.new(opts)}
  end

  def prepare(%Preparation{}, _opts), do: {:ok, %{}}

  @doc "Returns the three Connect catalog Action modules."
  def actions, do: [SearchTools, DescribeTool, CallTool]

  @doc "Returns Connect discovery data, not a Jido runtime Plugin spec."
  def plugin_spec(_config \\ %{}) do
    %{module: __MODULE__, name: "jido_connect_catalog", actions: actions()}
  end

  @doc "Returns route suggestions. The host declares its Agent routes explicitly."
  def signal_routes(_config \\ %{}), do: @signal_routes
end
