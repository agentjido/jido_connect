defmodule Jido.Connect.Asana.Section do
  @moduledoc "Normalized Asana section within a project."

  @schema Zoi.struct(
            __MODULE__,
            %{
              gid: Zoi.string(),
              name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              resource_type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              project_gid: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              created_at: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              modified_at: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
