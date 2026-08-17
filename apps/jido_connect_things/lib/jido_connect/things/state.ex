defmodule Jido.Connect.Things.State do
  @moduledoc """
  Storage-free current state folded from Things Cloud history.

  The state retains every raw event for replay and diagnosis. Unknown or
  malformed data marks the state unsafe for writes, but it does not discard
  the remaining readable state.
  """

  alias Jido.Connect.Things.{Identifier, Todo}
  alias Jido.Connect.Things.State.{ChecklistFold, ReferenceFold, TaskFold}

  @task_entities ~w(Task Task2 Task3 Task4 Task6)
  @checklist_entities ~w(ChecklistItem ChecklistItem2 ChecklistItem3)
  @area_entities ~w(Area Area2 Area3)
  @tag_entities ~w(Tag Tag2 Tag3 Tag4)

  @enforce_keys [
    :provider_head,
    :history_fingerprint,
    :last_server_index,
    :tasks,
    :checklist_items,
    :areas,
    :tags,
    :tombstones,
    :raw_events,
    :issues,
    :write_safe?
  ]
  defstruct @enforce_keys

  def new do
    %__MODULE__{
      provider_head: 0,
      history_fingerprint: nil,
      last_server_index: 0,
      tasks: %{},
      checklist_items: %{},
      areas: %{},
      tags: %{},
      tombstones: MapSet.new(),
      raw_events: [],
      issues: [],
      write_safe?: true
    }
  end

  def bind_history(%__MODULE__{history_fingerprint: nil} = state, fingerprint)
      when is_binary(fingerprint),
      do: %{state | history_fingerprint: fingerprint}

  def bind_history(%__MODULE__{history_fingerprint: fingerprint} = state, fingerprint), do: state

  def bind_history(%__MODULE__{}, fingerprint) when is_binary(fingerprint) do
    %{new() | history_fingerprint: fingerprint}
  end

  def apply_page(%__MODULE__{} = state, items, start_index)
      when is_list(items) and is_integer(start_index) and start_index >= 0 do
    if state.last_server_index == start_index do
      items
      |> Enum.with_index(start_index + 1)
      |> Enum.reduce_while({:ok, state}, fn {server_item, server_index}, {:ok, state} ->
        case apply_server_item(state, server_item, server_index) do
          {:ok, state} -> {:cont, {:ok, %{state | last_server_index: server_index}}}
          {:error, _reason} = error -> {:halt, error}
        end
      end)
    else
      {:error, issue(:history, :incremental_start_mismatch, start_index)}
    end
  end

  def apply_page(_state, _items, _start_index),
    do: {:error, issue(:history, :invalid_page, nil)}

  def finish(%__MODULE__{} = state, provider_head)
      when is_integer(provider_head) and provider_head >= 0 do
    if state.last_server_index == provider_head do
      {:ok, %{state | provider_head: provider_head}}
    else
      {:error,
       issue(:history, :incomplete_history, %{
         last_server_index: state.last_server_index,
         provider_head: provider_head
       })}
    end
  end

  def finish(_state, _provider_head),
    do: {:error, issue(:history, :invalid_provider_head, nil)}

  def task(%__MODULE__{} = state, id), do: Map.get(state.tasks, id)

  def active_tasks(%__MODULE__{} = state) do
    state.tasks
    |> Map.values()
    |> Enum.reject(& &1.deleted)
    |> attach_checklists(state.checklist_items)
  end

  def write_safe_task(%__MODULE__{write_safe?: true} = state, id) do
    case Map.get(state.tasks, id) do
      %Todo{} = todo when not todo.deleted and todo.state_complete -> {:ok, todo}
      %Todo{} -> {:error, :unsafe_task_state}
      nil -> {:error, :todo_not_found}
    end
  end

  def write_safe_task(%__MODULE__{}, _id), do: {:error, :unsafe_provider_state}

  defp apply_server_item(state, server_item, server_index) when is_map(server_item) do
    state =
      Enum.reduce(server_item, state, fn {id, event}, state ->
        {:ok, state} = apply_event(state, id, event, server_index)
        state
      end)

    {:ok, state}
  end

  defp apply_server_item(_state, _server_item, _server_index),
    do: {:error, issue(:history, :invalid_server_item, nil)}

  defp apply_event(state, id, event, server_index) do
    raw_event = %{server_index: server_index, id: id, event: event}
    state = %{state | raw_events: [raw_event | state.raw_events]}

    case Identifier.validate(id) do
      :ok -> dispatch_event(state, id, event, server_index)
      {:error, _reason} -> {:ok, add_issue(state, issue(:identifier, :unsafe_identifier, id))}
    end
  end

  defp dispatch_event(state, id, %{"e" => entity, "t" => 2}, server_index)
       when entity in @task_entities,
       do: {:ok, mark_deleted(state, :tasks, id, server_index)}

  defp dispatch_event(state, id, %{"e" => entity, "t" => 2}, server_index)
       when entity in @checklist_entities,
       do: {:ok, mark_deleted(state, :checklist_items, id, server_index)}

  defp dispatch_event(state, id, %{"e" => entity, "t" => 2}, server_index)
       when entity in @area_entities,
       do: {:ok, mark_deleted(state, :areas, id, server_index)}

  defp dispatch_event(state, id, %{"e" => entity, "t" => 2}, server_index)
       when entity in @tag_entities,
       do: {:ok, mark_deleted(state, :tags, id, server_index)}

  defp dispatch_event(state, _id, %{"e" => "Tombstone2", "t" => action, "p" => payload}, index)
       when action in [0, nil] and is_map(payload) do
    case Map.get(payload, "dloid") do
      target when is_binary(target) -> apply_tombstone(state, target, index)
      _value -> {:ok, add_issue(state, issue(:tombstone, :invalid_target, index))}
    end
  end

  defp dispatch_event(state, _id, %{"e" => "Tombstone2", "p" => payload}, index)
       when is_map(payload) do
    case Map.get(payload, "dloid") do
      target when is_binary(target) -> apply_tombstone(state, target, index)
      _value -> {:ok, add_issue(state, issue(:tombstone, :invalid_target, index))}
    end
  end

  defp dispatch_event(state, id, %{"e" => entity, "t" => action, "p" => payload}, index)
       when entity in @task_entities and action in [0, 1] and is_map(payload) do
    case TaskFold.apply(Map.get(state.tasks, id), entity, action, payload, index) do
      {:ok, task, issues} ->
        task = TaskFold.with_id(task, id)
        {:ok, state |> put_entity(:tasks, id, task) |> add_issues(id, entity, issues)}

      {:error, task_issue} ->
        {:ok, add_issue(state, contextual_issue(task_issue, id, entity, index))}
    end
  end

  defp dispatch_event(state, id, %{"e" => entity, "t" => action, "p" => payload}, index)
       when entity in @checklist_entities and action in [0, 1] and is_map(payload) do
    case ChecklistFold.apply(
           Map.get(state.checklist_items, id),
           id,
           entity,
           action,
           payload,
           index
         ) do
      {:ok, item, issues} ->
        {:ok, state |> put_entity(:checklist_items, id, item) |> add_issues(id, entity, issues)}

      {:error, item_issue} ->
        {:ok, add_issue(state, contextual_issue(item_issue, id, entity, index))}
    end
  end

  defp dispatch_event(state, id, %{"e" => entity, "t" => action, "p" => payload}, index)
       when entity in @area_entities and action in [0, 1] and is_map(payload) do
    case ReferenceFold.area(Map.get(state.areas, id), id, entity, action, payload, index) do
      {:ok, area, issues} ->
        {:ok, state |> put_entity(:areas, id, area) |> add_issues(id, entity, issues)}

      {:error, area_issue} ->
        {:ok, add_issue(state, contextual_issue(area_issue, id, entity, index))}
    end
  end

  defp dispatch_event(state, id, %{"e" => entity, "t" => action, "p" => payload}, index)
       when entity in @tag_entities and action in [0, 1] and is_map(payload) do
    case ReferenceFold.tag(Map.get(state.tags, id), id, entity, action, payload, index) do
      {:ok, tag, issues} ->
        {:ok, state |> put_entity(:tags, id, tag) |> add_issues(id, entity, issues)}

      {:error, tag_issue} ->
        {:ok, add_issue(state, contextual_issue(tag_issue, id, entity, index))}
    end
  end

  defp dispatch_event(state, id, event, server_index) do
    entity = if is_map(event), do: Map.get(event, "e"), else: nil
    action = if is_map(event), do: Map.get(event, "t"), else: nil

    {:ok,
     add_issue(
       state,
       issue(:event, :unsupported_event, %{
         id: id,
         entity: entity,
         action: action,
         server_index: server_index
       })
     )}
  end

  defp apply_tombstone(state, target, server_index) do
    case Identifier.validate(target) do
      :ok ->
        state =
          state
          |> mark_deleted(:tasks, target, server_index)
          |> mark_deleted(:checklist_items, target, server_index)
          |> mark_deleted(:areas, target, server_index)
          |> mark_deleted(:tags, target, server_index)

        checklist_items =
          Map.new(state.checklist_items, fn {id, item} ->
            if item.task_id == target do
              {id, %{item | deleted: true, last_server_index: server_index}}
            else
              {id, item}
            end
          end)

        {:ok,
         %{
           state
           | checklist_items: checklist_items,
             tombstones: MapSet.put(state.tombstones, target)
         }}

      {:error, _reason} ->
        {:ok, add_issue(state, issue(:tombstone, :unsafe_target, target))}
    end
  end

  defp put_entity(state, collection, id, value) do
    Map.update!(state, collection, &Map.put(&1, id, value))
  end

  defp mark_deleted(state, collection, id, server_index) do
    Map.update!(state, collection, fn values ->
      case Map.get(values, id) do
        nil -> values
        value -> Map.put(values, id, %{value | deleted: true, last_server_index: server_index})
      end
    end)
  end

  defp add_issues(state, _id, _entity, []), do: state

  defp add_issues(state, id, entity, issues) do
    Enum.reduce(issues, state, fn value, state ->
      add_issue(state, Map.merge(value, %{id: id, entity: entity}))
    end)
  end

  defp add_issue(state, value) do
    %{state | issues: [value | state.issues], write_safe?: false}
  end

  defp contextual_issue(value, id, entity, server_index) do
    Map.merge(value, %{id: id, entity: entity, server_index: server_index})
  end

  defp attach_checklists(tasks, checklist_items) do
    by_task =
      checklist_items
      |> Map.values()
      |> Enum.reject(& &1.deleted)
      |> Enum.group_by(& &1.task_id, & &1.id)

    Enum.map(tasks, fn task -> %{task | checklist_item_ids: Map.get(by_task, task.id, [])} end)
  end

  defp issue(scope, reason, details), do: %{scope: scope, reason: reason, details: details}
end
