defmodule Jido.Connect.Things.Todo do
  @moduledoc "Normalized Things to-do returned by the provider."

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.string(min_length: 1, max_length: 32),
              title: Zoi.string(min_length: 1, max_length: 2_000),
              notes: Zoi.string(max_length: 100_000) |> Zoi.default(""),
              modified_at: Zoi.datetime(),
              status: Zoi.enum([:open, :completed, :canceled]),
              schedule: Zoi.enum([:inbox, :anytime, :someday]),
              type: Zoi.enum([:task, :project, :heading]),
              in_trash: Zoi.boolean() |> Zoi.default(false),
              deleted: Zoi.boolean() |> Zoi.default(false)
            },
            coerce: true,
            unrecognized_keys: :error
          )

  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  def schema, do: @schema
  def new(attrs), do: Zoi.parse(@schema, attrs)
  def new!(attrs), do: Zoi.parse!(@schema, attrs)

  def eligible_inbox?(%__MODULE__{} = todo) do
    todo.status == :open and todo.schedule == :inbox and todo.type == :task and
      not todo.in_trash and not todo.deleted
  end

  def to_public_map(%__MODULE__{} = todo) do
    %{
      id: todo.id,
      title: todo.title,
      notes: todo.notes,
      modified_at: DateTime.to_iso8601(todo.modified_at),
      status: Atom.to_string(todo.status),
      schedule: Atom.to_string(todo.schedule)
    }
  end
end
