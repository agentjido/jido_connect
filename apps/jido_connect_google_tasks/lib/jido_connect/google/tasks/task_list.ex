defmodule Jido.Connect.Google.Tasks.TaskList do
  @moduledoc "Normalized Google Tasks task-list metadata."

  @schema Zoi.struct(
            __MODULE__,
            %{
              task_list_id: Zoi.string(),
              etag: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              title: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              updated: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              self_link: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
