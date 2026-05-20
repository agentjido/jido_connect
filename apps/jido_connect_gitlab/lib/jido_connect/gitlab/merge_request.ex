defmodule Jido.Connect.GitLab.MergeRequest do
  @moduledoc "Normalized GitLab merge request."

  alias Jido.Connect.GitLab.User

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.number(),
              iid: Zoi.number(),
              title: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              description: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              state: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              merge_status: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              source_branch: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              target_branch: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              author: User.schema() |> Zoi.nullish() |> Zoi.optional(),
              assignees: Zoi.list(User.schema()) |> Zoi.default([]),
              reviewers: Zoi.list(User.schema()) |> Zoi.default([]),
              project_id: Zoi.number() |> Zoi.nullish() |> Zoi.optional(),
              source_project_id: Zoi.number() |> Zoi.nullish() |> Zoi.optional(),
              target_project_id: Zoi.number() |> Zoi.nullish() |> Zoi.optional(),
              web_url: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              created_at: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              updated_at: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              merged_at: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              closed_at: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
