defmodule Jido.Connect.Jira.Transition do
  @moduledoc "Normalized Jira workflow transition."

  alias Jido.Connect.Jira.Status

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.string(),
              name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              to_status: Status.schema() |> Zoi.nullish() |> Zoi.optional(),
              has_screen: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              is_global: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              is_initial: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              is_conditional: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              fields: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
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
