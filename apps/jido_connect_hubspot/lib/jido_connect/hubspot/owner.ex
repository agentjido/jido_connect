defmodule Jido.Connect.HubSpot.Owner do
  @moduledoc "Normalized HubSpot CRM owner."

  @schema Zoi.struct(
            __MODULE__,
            %{
              owner_id: Zoi.string(),
              email: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              first_name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              last_name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              user_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              team_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              archived?: Zoi.boolean() |> Zoi.default(false),
              created_at: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              updated_at: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
