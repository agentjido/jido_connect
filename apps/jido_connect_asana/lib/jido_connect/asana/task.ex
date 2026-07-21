defmodule Jido.Connect.Asana.Task do
  @moduledoc "Normalized Asana task."

  @schema Zoi.struct(
            __MODULE__,
            %{
              gid: Zoi.string(),
              name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              resource_type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              assignee_gid: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              assignee_name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              assignee_status: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              completed: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              completed_at: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              due_on: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              due_at: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              start_on: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              start_at: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              notes: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              html_notes: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              num_hearts: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              num_likes: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              parent_gid: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              workspace_gid: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              project_gids: Zoi.list(Zoi.string()) |> Zoi.default([]),
              tag_gids: Zoi.list(Zoi.string()) |> Zoi.default([]),
              section_gid: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              custom_fields: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
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
