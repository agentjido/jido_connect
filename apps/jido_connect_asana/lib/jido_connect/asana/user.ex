defmodule Jido.Connect.Asana.User do
  @moduledoc "Normalized Asana user."

  @schema Zoi.struct(
            __MODULE__,
            %{
              gid: Zoi.string(),
              name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              resource_type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              email: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              photo: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              workspaces: Zoi.list(Zoi.map()) |> Zoi.nullish() |> Zoi.optional(),
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
