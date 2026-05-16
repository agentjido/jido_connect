defmodule Jido.Connect.Linear.Issue do
  @moduledoc "Normalized Linear issue."

  alias Jido.Connect.Linear.{Label, State, Team, User}

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.string(),
              identifier: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              title: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              description: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              state: State.schema() |> Zoi.nullish() |> Zoi.optional(),
              priority: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              priority_label: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              team: Team.schema() |> Zoi.nullish() |> Zoi.optional(),
              assignee: User.schema() |> Zoi.nullish() |> Zoi.optional(),
              creator: User.schema() |> Zoi.nullish() |> Zoi.optional(),
              labels: Zoi.list(Label.schema()) |> Zoi.default([]),
              due_date: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              estimate: Zoi.number() |> Zoi.nullish() |> Zoi.optional(),
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
