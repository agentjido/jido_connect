defmodule Jido.Connect.Jira.Status do
  @moduledoc "Normalized Jira issue status."

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.string(),
              name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              category: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              description: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              icon_url: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
