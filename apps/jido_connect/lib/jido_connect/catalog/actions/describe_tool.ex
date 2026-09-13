defmodule Jido.Connect.Catalog.Actions.DescribeTool do
  @moduledoc "Describe one installed Jido Connect catalog tool."

  use Jido.Action,
    name: "connect_catalog_describe",
    description: "Describe one Jido Connect catalog tool",
    schema:
      Zoi.object(
        %{
          tool_id: Zoi.string(),
          provider: Zoi.string() |> Zoi.optional(),
          filters: Zoi.map() |> Zoi.optional(),
          pack: Zoi.any() |> Zoi.optional()
        },
        coerce: true
      ),
    output_schema: Zoi.object(%{descriptor: Zoi.map()})

  alias Jido.Connect.Catalog
  alias Jido.Connect.Catalog.Input

  @impl true
  def run(params, context) do
    with {:ok, tool_ref, opts} <- Input.describe_params(params, context),
         {:ok, descriptor} <- Catalog.describe_tool(tool_ref, opts) do
      {:ok, %{descriptor: Catalog.to_map(descriptor)}}
    end
  end
end
