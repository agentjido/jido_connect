defmodule Jido.Connect.MCP.ToolResult do
  @moduledoc "Normalized MCP tool call result exposed by the bridge."

  @schema Zoi.struct(
            __MODULE__,
            %{
              endpoint_id: Zoi.string(),
              tool_name: Zoi.string(),
              content: Zoi.list(Zoi.map()) |> Zoi.default([]),
              is_error?: Zoi.boolean() |> Zoi.default(false),
              raw: Zoi.map() |> Zoi.default(%{})
            },
            coerce: true
          )

  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  def schema, do: @schema
  def new!(attrs), do: Zoi.parse!(@schema, attrs)
  def new(attrs), do: Zoi.parse(@schema, attrs)

  def from_mcp(endpoint_id, tool_name, %{} = data) do
    new!(%{
      endpoint_id: to_string(endpoint_id),
      tool_name: tool_name,
      content: Jido.Connect.Data.get(data, "content", []),
      is_error?: Jido.Connect.Data.get(data, "isError", false),
      raw: data
    })
  end

  def to_map(%__MODULE__{} = result) do
    %{
      endpoint_id: result.endpoint_id,
      tool_name: result.tool_name,
      content: result.content,
      is_error?: result.is_error?,
      raw: result.raw
    }
  end
end
