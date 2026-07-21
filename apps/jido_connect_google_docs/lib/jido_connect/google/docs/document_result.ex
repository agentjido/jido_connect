defmodule Jido.Connect.Google.Docs.DocumentResult do
  @moduledoc "Normalized Google Docs document read/create/batch-update result."

  @schema Zoi.struct(
            __MODULE__,
            %{
              document_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              title: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              revision_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              metadata: Zoi.map() |> Zoi.default(%{})
            },
            coerce: true
          )

  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  def schema, do: @schema
  def new!(attrs), do: Zoi.parse!(@schema, attrs)
  def new(attrs), do: Zoi.parse(@schema, attrs)
end
