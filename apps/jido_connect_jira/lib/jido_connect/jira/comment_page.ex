defmodule Jido.Connect.Jira.CommentPage do
  @moduledoc """
  One page of an issue's comments, as returned by `jira.issue.comment.list`.

  `issue` is the issue key or ID exactly as the caller supplied it. `start_at`,
  `max_results` and `total` are Jira's `startAt`, `maxResults` and `total`.
  `is_last` is `true` when `start_at` plus the number of comments reaches
  `total`. `next_start_at` is `start_at` plus the number of comments. On the
  last page it is `nil`, and the output of `jira.issue.comment.list` leaves
  it out.
  """

  alias Jido.Connect.Jira.Comment

  @schema Zoi.struct(
            __MODULE__,
            %{
              issue: Zoi.string(),
              comments: Zoi.list(Comment.schema()) |> Zoi.default([]),
              start_at: Zoi.integer(),
              max_results: Zoi.integer(),
              total: Zoi.integer(),
              is_last: Zoi.boolean(),
              next_start_at: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
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
