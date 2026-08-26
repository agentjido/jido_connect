defmodule Jido.Connect.Catalog.Actions.CallTool do
  @moduledoc "Call one Jido Connect catalog action through the core runtime boundary."

  use Jido.Action,
    name: "connect_catalog_call",
    description: "Call one Jido Connect catalog action",
    schema:
      Zoi.object(
        %{
          tool_id: Zoi.string(),
          provider: Zoi.string() |> Zoi.optional(),
          input: Zoi.map(),
          filters: Zoi.map() |> Zoi.optional(),
          pack: Zoi.any() |> Zoi.optional()
        },
        coerce: true
      ),
    output_schema: Zoi.object(%{result: Zoi.any()})

  alias Jido.Connect.Catalog
  alias Jido.Connect.Catalog.Input

  @impl true
  def run(params, context) do
    with {:ok, tool_ref, input, opts} <- Input.call_params(params, context),
         {:ok, result} <- Catalog.call_tool(tool_ref, input, opts) do
      {:ok, %{result: result}}
    end
  end
end
