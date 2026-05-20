defmodule Jido.Connect.GitLab.User do
  @moduledoc "Normalized GitLab user."

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.number(),
              username: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              email: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              avatar_url: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              state: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              web_url: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
