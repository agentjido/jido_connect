defmodule Jido.Connect.MCP.Tool do
  @moduledoc "Normalized MCP tool metadata exposed by the bridge."

  @schema Zoi.struct(
            __MODULE__,
            %{
              name: Zoi.string(),
              description: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              input_schema: Zoi.map() |> Zoi.default(%{}),
              schema_hash: Zoi.string() |> Zoi.default(""),
              annotations: Zoi.map() |> Zoi.default(%{}),
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

  def from_mcp(%{} = tool) do
    input_schema = get(tool, "inputSchema", %{})

    new!(%{
      name: get(tool, "name"),
      description: get(tool, "description"),
      input_schema: input_schema,
      schema_hash: schema_hash(input_schema),
      annotations: get(tool, "annotations", %{}),
      raw: tool
    })
  end

  def to_map(%__MODULE__{} = tool) do
    %{
      name: tool.name,
      description: tool.description,
      input_schema: tool.input_schema,
      schema_hash: tool.schema_hash,
      annotations: tool.annotations,
      raw: tool.raw
    }
  end

  @doc "Returns a stable SHA-256 hash for an MCP tool input schema."
  @spec schema_hash(map()) :: String.t()
  def schema_hash(schema) when is_map(schema) do
    schema
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp get(map, key, default \\ nil), do: Jido.Connect.Data.get(map, key, default)
end
