defmodule Jido.Connect.Jira.Issue do
  @moduledoc "Normalized Jira issue."

  alias Jido.Connect.Jira.{Status, User}

  @schema Zoi.struct(
            __MODULE__,
            %{
              key: Zoi.string(),
              id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              url: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              summary: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              description: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              status: Status.schema() |> Zoi.nullish() |> Zoi.optional(),
              issue_type: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              project: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              assignee: User.schema() |> Zoi.nullish() |> Zoi.optional(),
              reporter: User.schema() |> Zoi.nullish() |> Zoi.optional(),
              priority: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              labels: Zoi.list(Zoi.string()) |> Zoi.default([]),
              components: Zoi.list(Zoi.map()) |> Zoi.default([]),
              fix_versions: Zoi.list(Zoi.map()) |> Zoi.default([]),
              due_date: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              resolution: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              time_tracking: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
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
