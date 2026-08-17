defmodule Jido.Connect.Things.Todo do
  @moduledoc "Normalized Things to-do returned by the provider."

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.string(min_length: 1, max_length: 32),
              entity_version: Zoi.string() |> Zoi.default("Task6"),
              title: Zoi.string(max_length: 2_000) |> Zoi.default(""),
              notes: Zoi.string(max_length: 100_000) |> Zoi.default(""),
              note_state: Zoi.enum([:complete, :incomplete]) |> Zoi.default(:complete),
              created_at: Zoi.datetime() |> Zoi.nullish() |> Zoi.optional(),
              modified_at: Zoi.datetime() |> Zoi.nullish() |> Zoi.optional(),
              stopped_at: Zoi.datetime() |> Zoi.nullish() |> Zoi.optional(),
              scheduled_at: Zoi.datetime() |> Zoi.nullish() |> Zoi.optional(),
              today_reference_at: Zoi.datetime() |> Zoi.nullish() |> Zoi.optional(),
              deadline_at: Zoi.datetime() |> Zoi.nullish() |> Zoi.optional(),
              status: Zoi.enum([:open, :completed, :canceled]),
              schedule: Zoi.enum([:inbox, :anytime, :someday]) |> Zoi.nullish() |> Zoi.optional(),
              type: Zoi.enum([:task, :project, :heading]),
              position: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              today_position: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              in_trash: Zoi.boolean() |> Zoi.default(false),
              evening: Zoi.boolean() |> Zoi.default(false),
              area_ids: Zoi.list(Zoi.string()) |> Zoi.default([]),
              project_ids: Zoi.list(Zoi.string()) |> Zoi.default([]),
              heading_ids: Zoi.list(Zoi.string()) |> Zoi.default([]),
              tag_ids: Zoi.list(Zoi.string()) |> Zoi.default([]),
              checklist_item_ids: Zoi.list(Zoi.string()) |> Zoi.default([]),
              recurrence_rule: Zoi.any() |> Zoi.nullish() |> Zoi.optional(),
              recurrence_template_ids: Zoi.list(Zoi.string()) |> Zoi.default([]),
              recurrence_paused: Zoi.boolean() |> Zoi.default(false),
              recurrence_state_present: Zoi.boolean() |> Zoi.default(false),
              alarm_time_offset: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              reminder_present: Zoi.boolean() |> Zoi.default(false),
              deleted: Zoi.boolean() |> Zoi.default(false),
              state_complete: Zoi.boolean() |> Zoi.default(true),
              last_server_index: Zoi.integer() |> Zoi.default(0),
              unknown_fields: Zoi.map() |> Zoi.default(%{})
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

  def visible_open_inbox?(%__MODULE__{} = todo) do
    todo.status == :open and todo.schedule == :inbox and todo.type == :task and
      not todo.in_trash and not todo.deleted
  end

  def eligible_inbox?(%__MODULE__{} = todo) do
    visible_open_inbox?(todo) and write_safe?(todo)
  end

  def write_safe?(%__MODULE__{} = todo) do
    todo.entity_version == "Task6" and todo.state_complete and todo.note_state == :complete and
      not todo.recurrence_state_present and not todo.reminder_present and
      match?(%DateTime{}, concurrency_at(todo))
  end

  def concurrency_at(%__MODULE__{} = todo), do: todo.modified_at || todo.created_at

  def to_public_map(%__MODULE__{} = todo) do
    %{
      id: todo.id,
      title: todo.title,
      notes: todo.notes,
      modified_at: iso8601(todo.modified_at),
      expected_modified_at: iso8601(concurrency_at(todo)),
      status: Atom.to_string(todo.status),
      schedule: Atom.to_string(todo.schedule)
    }
  end

  defp iso8601(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp iso8601(_value), do: nil
end
