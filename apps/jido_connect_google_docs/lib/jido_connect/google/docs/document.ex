defmodule Jido.Connect.Google.Docs.Document do
  @moduledoc "Normalized Google Docs document metadata."

  @schema Zoi.struct(
            __MODULE__,
            %{
              document_id: Zoi.string(),
              title: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              revision_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              suggestions_view_mode: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              body: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              document_style: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              tabs: Zoi.list(Jido.Connect.Google.Docs.Tab.schema()) |> Zoi.default([]),
              named_styles: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
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
