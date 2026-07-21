defmodule Jido.Connect.Google.Tasks.Task do
  @moduledoc "Normalized Google Tasks task metadata."

  alias Jido.Connect.Google.Tasks.Link

  @schema Zoi.struct(
            __MODULE__,
            %{
              task_id: Zoi.string(),
              task_list_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              etag: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              title: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              updated: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              self_link: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              parent: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              position: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              notes: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              status: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              due: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              completed: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              deleted?: Zoi.boolean() |> Zoi.default(false),
              hidden?: Zoi.boolean() |> Zoi.default(false),
              links: Zoi.list(Link.schema()) |> Zoi.default([]),
              web_view_link: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
