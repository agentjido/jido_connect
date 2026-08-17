defmodule Jido.Connect.Things.ChangePlanner do
  @moduledoc false

  alias Jido.Connect.Things.{Identifier, Protocol, State, Todo, WriteWire}

  @target_actions [
    "things.todo.update",
    "things.todo.schedule",
    "things.todo.deadline.set",
    "things.todo.deadline.clear",
    "things.todo.tags.set",
    "things.todo.move",
    "things.todo.complete",
    "things.todo.cancel",
    "things.todo.reopen",
    "things.todo.trash",
    "things.todo.restore"
  ]

  def prepare("things.todo.create", input, %State{} = state, opts) do
    id = Keyword.fetch!(opts, :id)
    timestamp = Keyword.fetch!(opts, :timestamp)
    today = Keyword.fetch!(opts, :today)

    with :ok <- validate_state(state),
         :ok <- validate_identifier(id, :target_id),
         {:ok, normalized} <- normalize_create(input, state),
         {:ok, operation} <- WriteWire.create_task(id, normalized, timestamp, today) do
      {:ok,
       %{
         operation: operation,
         expected_modified_at: nil,
         risk: :normal,
         preview: %{
           operation: "create",
           target_id: id,
           before: nil,
           after: preview_values(normalized),
           changed_fields: changed_create_fields(normalized)
         }
       }}
    end
  end

  def prepare(action_id, input, %State{} = state, opts) when action_id in @target_actions do
    timestamp = Keyword.fetch!(opts, :timestamp)
    today = Keyword.fetch!(opts, :today)

    with :ok <- validate_state(state),
         :ok <- validate_identifier(input.id, :id),
         {:ok, todo} <- target(state, input.id),
         :ok <- validate_trash(action_id, todo),
         :ok <- validate_expected_modified_at(todo, input.expected_modified_at),
         {:ok, attrs, before_values, after_values, risk} <-
           change(action_id, input, todo, state, timestamp),
         {:ok, operation} <- WriteWire.update(todo.id, attrs, timestamp, today) do
      {:ok,
       %{
         operation: operation,
         expected_modified_at: input.expected_modified_at,
         risk: risk,
         preview: %{
           operation: action_name(action_id),
           target_id: todo.id,
           before: before_values,
           after: after_values,
           changed_fields:
             after_values |> Map.keys() |> Enum.map(&Atom.to_string/1) |> Enum.sort(),
           expected_modified_at: input.expected_modified_at
         }
       }}
    end
  end

  def prepare(action_id, _input, _state, _opts),
    do: Protocol.error(:unsupported_write_action, %{action_id: action_id})

  defp normalize_create(input, state) do
    relations = relation_ids(input)
    schedule = Map.get(input, :schedule, "inbox")
    explicit_schedule? = Map.has_key?(input, :schedule)

    with :ok <- validate_tags(state, Map.get(input, :tag_ids, [])),
         :ok <- validate_relations(state, relations),
         {:ok, schedule} <- normalize_container_schedule(schedule, relations, explicit_schedule?) do
      {:ok,
       input
       |> Map.put(:schedule, schedule)
       |> Map.put(:area_ids, relations.area_ids)
       |> Map.put(:project_ids, relations.project_ids)
       |> Map.put(:heading_ids, relations.heading_ids)}
    end
  end

  defp change("things.todo.update", input, todo, _state, _timestamp) do
    attrs = Map.take(input, [:title, :notes])
    before_values = Map.new(Map.keys(attrs), &{&1, preview_field(&1, Map.get(todo, &1))})
    after_values = Map.new(attrs, fn {key, value} -> {key, preview_field(key, value)} end)
    risk = if Map.has_key?(attrs, :notes) and todo.notes != "", do: :high, else: :normal
    {:ok, attrs, before_values, after_values, risk}
  end

  defp change("things.todo.schedule", input, todo, _state, _timestamp) do
    value = input.schedule
    {:ok, %{schedule: value}, %{schedule: schedule_value(todo)}, %{schedule: value}, :normal}
  end

  defp change("things.todo.deadline.set", input, todo, _state, _timestamp) do
    {:ok, %{deadline: input.deadline}, %{deadline: date_value(todo.deadline_at)},
     %{deadline: input.deadline}, :normal}
  end

  defp change("things.todo.deadline.clear", _input, todo, _state, _timestamp) do
    {:ok, %{deadline: nil}, %{deadline: date_value(todo.deadline_at)}, %{deadline: nil}, :normal}
  end

  defp change("things.todo.tags.set", input, todo, state, _timestamp) do
    with :ok <- validate_tags(state, input.tag_ids) do
      {:ok, %{tag_ids: input.tag_ids}, %{tag_ids: todo.tag_ids}, %{tag_ids: input.tag_ids},
       :normal}
    end
  end

  defp change("things.todo.move", input, todo, state, _timestamp) do
    relations = relation_ids(input)
    explicit_schedule? = Map.has_key?(input, :schedule)
    requested_schedule = Map.get(input, :schedule, schedule_value(todo))

    with :ok <- validate_relations(state, relations),
         {:ok, schedule} <-
           normalize_container_schedule(requested_schedule, relations, explicit_schedule?) do
      attrs = %{
        area_ids: relations.area_ids,
        project_ids: relations.project_ids,
        heading_ids: relations.heading_ids
      }

      attrs =
        if schedule != schedule_value(todo), do: Map.put(attrs, :schedule, schedule), else: attrs

      before_values = %{
        area_ids: todo.area_ids,
        project_ids: todo.project_ids,
        heading_ids: todo.heading_ids,
        schedule: schedule_value(todo)
      }

      after_values = Map.merge(relations, %{schedule: schedule})
      {:ok, attrs, before_values, after_values, :normal}
    end
  end

  defp change("things.todo.complete", _input, %Todo{status: :open} = todo, _state, timestamp) do
    status_change(todo, :completed, timestamp)
  end

  defp change("things.todo.cancel", _input, %Todo{status: :open} = todo, _state, timestamp) do
    status_change(todo, :canceled, timestamp)
  end

  defp change("things.todo.reopen", _input, %Todo{status: status} = todo, _state, _timestamp)
       when status in [:completed, :canceled] do
    {:ok, %{status: :open, stopped_at: nil}, %{status: Atom.to_string(todo.status)},
     %{status: "open"}, :normal}
  end

  defp change("things.todo.complete", _input, todo, _state, _timestamp),
    do:
      Protocol.error(:invalid_status_transition, %{
        id: todo.id,
        status: todo.status,
        action: :complete
      })

  defp change("things.todo.cancel", _input, todo, _state, _timestamp),
    do:
      Protocol.error(:invalid_status_transition, %{
        id: todo.id,
        status: todo.status,
        action: :cancel
      })

  defp change("things.todo.reopen", _input, todo, _state, _timestamp),
    do:
      Protocol.error(:invalid_status_transition, %{
        id: todo.id,
        status: todo.status,
        action: :reopen
      })

  defp change("things.todo.trash", _input, %Todo{in_trash: false}, _state, _timestamp) do
    {:ok, %{in_trash: true}, %{in_trash: false}, %{in_trash: true}, :destructive}
  end

  defp change("things.todo.trash", _input, todo, _state, _timestamp),
    do: Protocol.error(:already_in_trash, %{id: todo.id})

  defp change("things.todo.restore", _input, %Todo{in_trash: true}, _state, _timestamp) do
    {:ok, %{in_trash: false}, %{in_trash: true}, %{in_trash: false}, :normal}
  end

  defp change("things.todo.restore", _input, todo, _state, _timestamp),
    do: Protocol.error(:not_in_trash, %{id: todo.id})

  defp status_change(todo, status, timestamp) do
    {:ok, %{status: status, stopped_at: timestamp}, %{status: Atom.to_string(todo.status)},
     %{status: Atom.to_string(status)}, :normal}
  end

  defp target(state, id) do
    case State.write_safe_task(state, id) do
      {:ok, %Todo{entity_version: "Task6", type: :task} = todo} ->
        if Todo.write_safe?(todo),
          do: {:ok, todo},
          else: Protocol.error(:unsafe_task_state, %{id: id})

      {:ok, %Todo{} = todo} ->
        Protocol.error(:unsupported_write_target, %{
          id: id,
          entity: todo.entity_version,
          type: todo.type
        })

      {:error, reason} ->
        Protocol.error(reason, %{id: id})
    end
  end

  defp validate_state(%State{}), do: :ok

  defp validate_trash("things.todo.restore", %Todo{in_trash: true}), do: :ok

  defp validate_trash("things.todo.restore", todo),
    do: Protocol.error(:not_in_trash, %{id: todo.id})

  defp validate_trash(_action_id, %Todo{in_trash: false}), do: :ok
  defp validate_trash(_action_id, todo), do: Protocol.error(:target_in_trash, %{id: todo.id})

  defp validate_expected_modified_at(todo, expected) do
    concurrency_at = Todo.concurrency_at(todo)
    actual = DateTime.to_iso8601(concurrency_at)

    case DateTime.from_iso8601(expected) do
      {:ok, expected_datetime, 0} ->
        if DateTime.compare(expected_datetime, concurrency_at) == :eq,
          do: :ok,
          else:
            Protocol.error(:stale_expected_modified_at, %{
              id: todo.id,
              actual_modified_at: actual
            })

      _other ->
        Protocol.error(:stale_expected_modified_at, %{id: todo.id, actual_modified_at: actual})
    end
  end

  defp validate_identifier(value, field) do
    case Identifier.validate(value) do
      :ok ->
        :ok

      {:error, reason} ->
        Protocol.error(:unsafe_identifier, %{field: field, identifier_reason: reason})
    end
  end

  defp validate_tags(state, ids) do
    with :ok <- unique_ids(ids, :tag_ids) do
      Enum.reduce_while(ids, :ok, fn id, :ok ->
        case Map.get(state.tags, id) do
          %{entity_version: "Tag4", deleted: false, state_complete: true} -> {:cont, :ok}
          _value -> {:halt, Protocol.error(:invalid_tag_destination, %{id: id})}
        end
      end)
    end
  end

  defp validate_relations(state, relations) do
    with :ok <- relation_shape(relations),
         :ok <- validate_area(state, relations.area_ids),
         :ok <- validate_project(state, relations.project_ids),
         :ok <- validate_heading(state, relations.heading_ids, relations.project_ids) do
      :ok
    end
  end

  defp relation_shape(%{area_ids: area, project_ids: project, heading_ids: heading}) do
    cond do
      length(area) > 1 or length(project) > 1 or length(heading) > 1 ->
        Protocol.error(:invalid_container_shape)

      area != [] and (project != [] or heading != []) ->
        Protocol.error(:invalid_container_shape)

      heading != [] and project == [] ->
        Protocol.error(:heading_requires_project)

      true ->
        :ok
    end
  end

  defp validate_area(_state, []), do: :ok

  defp validate_area(state, [id]) do
    case Map.get(state.areas, id) do
      %{entity_version: "Area3", deleted: false, state_complete: true} -> :ok
      _value -> Protocol.error(:invalid_area_destination, %{id: id})
    end
  end

  defp validate_project(_state, []), do: :ok

  defp validate_project(state, [id]) do
    case Map.get(state.tasks, id) do
      %Todo{
        entity_version: "Task6",
        type: :project,
        deleted: false,
        in_trash: false,
        state_complete: true
      } ->
        :ok

      _value ->
        Protocol.error(:invalid_project_destination, %{id: id})
    end
  end

  defp validate_heading(_state, [], _project_ids), do: :ok

  defp validate_heading(state, [id], [project_id]) do
    case Map.get(state.tasks, id) do
      %Todo{
        entity_version: "Task6",
        type: :heading,
        deleted: false,
        in_trash: false,
        state_complete: true,
        project_ids: project_ids
      } ->
        if project_id in project_ids,
          do: :ok,
          else: Protocol.error(:heading_project_mismatch, %{id: id, project_id: project_id})

      _value ->
        Protocol.error(:invalid_heading_destination, %{id: id})
    end
  end

  defp relation_ids(input) do
    %{
      area_ids: singleton(Map.get(input, :area_id)),
      project_ids: singleton(Map.get(input, :project_id)),
      heading_ids: singleton(Map.get(input, :heading_id))
    }
  end

  defp singleton(nil), do: []
  defp singleton(value), do: [value]

  defp unique_ids(ids, field) when is_list(ids) do
    cond do
      Enum.uniq(ids) != ids ->
        Protocol.error(:duplicate_identifier, %{field: field})

      true ->
        Enum.reduce_while(ids, :ok, fn id, :ok ->
          case validate_identifier(id, field) do
            :ok -> {:cont, :ok}
            error -> {:halt, error}
          end
        end)
    end
  end

  defp normalize_container_schedule("inbox", relations, true) do
    if container?(relations),
      do: Protocol.error(:container_cannot_be_inbox),
      else: {:ok, "inbox"}
  end

  defp normalize_container_schedule("inbox", relations, false) do
    if container?(relations), do: {:ok, "anytime"}, else: {:ok, "inbox"}
  end

  defp normalize_container_schedule(value, _relations, _explicit), do: {:ok, value}
  defp container?(relations), do: relations.area_ids != [] or relations.project_ids != []

  defp preview_values(input) do
    %{
      title: input.title,
      notes: preview_field(:notes, Map.get(input, :notes, "")),
      schedule: input.schedule,
      deadline: Map.get(input, :deadline),
      tag_ids: Map.get(input, :tag_ids, []),
      area_ids: Map.get(input, :area_ids, []),
      project_ids: Map.get(input, :project_ids, []),
      heading_ids: Map.get(input, :heading_ids, [])
    }
  end

  defp preview_field(:notes, value) do
    %{
      length: String.length(value),
      sha256: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
    }
  end

  defp preview_field(_field, value), do: value

  defp changed_create_fields(input) do
    [:title, :notes, :schedule, :deadline, :tag_ids, :area_ids, :project_ids, :heading_ids]
    |> Enum.filter(&Map.has_key?(input, &1))
    |> Enum.map(&Atom.to_string/1)
  end

  defp schedule_value(%Todo{scheduled_at: %DateTime{} = value, evening: true}),
    do:
      if(DateTime.to_date(value) == Date.utc_today(),
        do: "evening",
        else: Date.to_iso8601(DateTime.to_date(value))
      )

  defp schedule_value(%Todo{scheduled_at: %DateTime{} = value}),
    do: Date.to_iso8601(DateTime.to_date(value))

  defp schedule_value(%Todo{schedule: value}) when is_atom(value), do: Atom.to_string(value)
  defp schedule_value(_todo), do: nil

  defp date_value(%DateTime{} = value), do: value |> DateTime.to_date() |> Date.to_iso8601()
  defp date_value(_value), do: nil
  defp action_name(action_id), do: String.replace_prefix(action_id, "things.todo.", "")
end
