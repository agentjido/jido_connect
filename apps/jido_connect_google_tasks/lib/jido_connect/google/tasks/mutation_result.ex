defmodule Jido.Connect.Google.Tasks.MutationResult do
  @moduledoc "Normalized Google Tasks mutation (create / update / delete) result."

  @schema Zoi.struct(
            __MODULE__,
            %{
              operation: Zoi.atom() |> Zoi.nullish() |> Zoi.optional(),
              resource_type: Zoi.atom() |> Zoi.nullish() |> Zoi.optional(),
              resource_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              status: Zoi.atom() |> Zoi.nullish() |> Zoi.optional(),
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
