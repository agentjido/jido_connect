defmodule Jido.Connect.Things.Query do
  @moduledoc "Read-only filters and safe public maps for Things V1 state."

  alias Jido.Connect.Things.{Protocol, State, Todo}

  @views ~w(all inbox today evening anytime someday upcoming logbook trash)
  @statuses ~w(all open completed canceled)

  def list(%State{} = state, input, opts \\ []) when is_map(input) do
    today = Keyword.get(opts, :today, Date.utc_today())

    with {:ok, filters} <- normalize_filters(input),
         {:ok, tasks} <- filter_tasks(state, filters, today) do
      tasks = tasks |> sort(filters.view) |> Enum.take(filters.limit)

      {:ok,
       %{
         view: filters.view,
         count: length(tasks),
         todos: Enum.map(tasks, &todo_map(&1, state)),
         freshness: freshness(state)
       }}
    end
  end

  def search(%State{} = state, input, opts \\ []) when is_map(input) do
    list(state, Map.put(input, :view, Map.get(input, :view, "all")), opts)
  end

  def get(%State{} = state, id) when is_binary(id) do
    with {:ok, todo} <- resolve_task(state, id) do
      {:ok, %{todo: todo_map(todo, state), freshness: freshness(state)}}
    end
  end

  def references(%State{} = state, :project) do
    list_references(state, :projects, fn ->
      state.tasks
      |> Map.values()
      |> Enum.filter(&(&1.type == :project and not &1.deleted and not &1.in_trash))
      |> Enum.map(&todo_map(&1, state))
    end)
  end

  def references(%State{} = state, :heading) do
    list_references(state, :headings, fn ->
      state.tasks
      |> Map.values()
      |> Enum.filter(&(&1.type == :heading and not &1.deleted and not &1.in_trash))
      |> Enum.map(&todo_map(&1, state))
    end)
  end

  def references(%State{} = state, :area) do
    list_references(state, :areas, fn ->
      state.areas
      |> Map.values()
      |> Enum.reject(& &1.deleted)
      |> Enum.map(&reference_map/1)
    end)
  end

  def references(%State{} = state, :tag) do
    list_references(state, :tags, fn ->
      state.tags
      |> Map.values()
      |> Enum.reject(& &1.deleted)
      |> Enum.map(&reference_map/1)
    end)
  end

  defp normalize_filters(input) do
    with {:ok, view} <- member(Map.get(input, :view, "all"), @views, :view),
         {:ok, status} <- member(Map.get(input, :status, "all"), @statuses, :status),
         {:ok, deadline_from} <- date(Map.get(input, :deadline_from), :deadline_from),
         {:ok, deadline_to} <- date(Map.get(input, :deadline_to), :deadline_to),
         {:ok, scheduled_from} <- date(Map.get(input, :scheduled_from), :scheduled_from),
         {:ok, scheduled_to} <- date(Map.get(input, :scheduled_to), :scheduled_to),
         :ok <- ordered_range(deadline_from, deadline_to, :deadline),
         :ok <- ordered_range(scheduled_from, scheduled_to, :scheduled) do
      {:ok,
       %{
         view: view,
         status: status,
         query: normalize_query(Map.get(input, :query)),
         area_id: Map.get(input, :area_id),
         project_id: Map.get(input, :project_id),
         heading_id: Map.get(input, :heading_id),
         tag_ids: Map.get(input, :tag_ids, []),
         deadline_from: deadline_from,
         deadline_to: deadline_to,
         scheduled_from: scheduled_from,
         scheduled_to: scheduled_to,
         limit: Map.get(input, :limit, 25)
       }}
    end
  end

  defp filter_tasks(state, filters, today) do
    tasks =
      state.tasks
      |> Map.values()
      |> Enum.filter(&(&1.type == :task and not &1.deleted))
      |> Enum.filter(&view_match?(&1, filters.view, today))
      |> Enum.filter(&status_match?(&1, filters.status))
      |> Enum.filter(&text_match?(&1, filters.query))
      |> Enum.filter(&relation_match?(&1, filters))
      |> Enum.filter(&date_match?(&1.deadline_at, filters.deadline_from, filters.deadline_to))
      |> Enum.filter(
        &date_match?(
          &1.scheduled_at || &1.today_reference_at,
          filters.scheduled_from,
          filters.scheduled_to
        )
      )

    {:ok, tasks}
  end

  defp view_match?(_task, "all", _today), do: true

  defp view_match?(task, "inbox", _today),
    do: task.status == :open and task.schedule == :inbox and not task.in_trash

  defp view_match?(task, "today", today),
    do: task.status == :open and not task.in_trash and today_match?(task, today)

  defp view_match?(task, "evening", today),
    do: task.status == :open and not task.in_trash and task.evening and today_match?(task, today)

  defp view_match?(task, "anytime", today) do
    task.status == :open and not task.in_trash and task.schedule == :anytime and
      not future?(task, today)
  end

  defp view_match?(task, "someday", today) do
    task.status == :open and not task.in_trash and task.schedule == :someday and
      not future?(task, today)
  end

  defp view_match?(task, "upcoming", today),
    do: task.status == :open and not task.in_trash and future?(task, today)

  defp view_match?(task, "logbook", _today),
    do: task.status in [:completed, :canceled] and not task.in_trash

  defp view_match?(task, "trash", _today), do: task.in_trash

  defp status_match?(_task, "all"), do: true
  defp status_match?(task, value), do: Atom.to_string(task.status) == value

  defp text_match?(_task, nil), do: true

  defp text_match?(task, query) do
    String.contains?(String.downcase(task.title), query) or
      String.contains?(String.downcase(task.notes), query)
  end

  defp relation_match?(task, filters) do
    optional_relation?(filters.area_id, task.area_ids) and
      optional_relation?(filters.project_id, task.project_ids) and
      optional_relation?(filters.heading_id, task.heading_ids) and
      Enum.all?(filters.tag_ids, &(&1 in task.tag_ids))
  end

  defp optional_relation?(nil, _values), do: true
  defp optional_relation?(value, values), do: value in values

  defp date_match?(_datetime, nil, nil), do: true
  defp date_match?(nil, _from, _to), do: false

  defp date_match?(%DateTime{} = datetime, from, to) do
    value = DateTime.to_date(datetime)

    (is_nil(from) or Date.compare(value, from) in [:eq, :gt]) and
      (is_nil(to) or Date.compare(value, to) in [:eq, :lt])
  end

  defp today_match?(task, today) do
    Enum.any?([task.scheduled_at, task.today_reference_at, task.deadline_at], fn
      %DateTime{} = value -> Date.compare(DateTime.to_date(value), today) == :eq
      _value -> false
    end)
  end

  defp future?(task, today) do
    case task.scheduled_at || task.today_reference_at do
      %DateTime{} = value -> Date.compare(DateTime.to_date(value), today) == :gt
      _value -> false
    end
  end

  defp sort(tasks, view) when view in ["today", "evening"] do
    Enum.sort_by(tasks, &{&1.today_position || 0, &1.position || 0, downcase(&1.title), &1.id})
  end

  defp sort(tasks, "upcoming") do
    Enum.sort_by(
      tasks,
      &{date_value(&1.scheduled_at || &1.today_reference_at), &1.position || 0, &1.id}
    )
  end

  defp sort(tasks, _view) do
    Enum.sort_by(tasks, &{&1.position || 0, downcase(&1.title), &1.id})
  end

  defp resolve_task(state, id) do
    case Map.get(state.tasks, id) do
      %Todo{deleted: false} = todo ->
        {:ok, todo}

      _value ->
        candidates =
          state.tasks
          |> Map.values()
          |> Enum.filter(&(not &1.deleted and String.starts_with?(&1.id, id)))
          |> Enum.sort_by(& &1.id)

        case candidates do
          [todo] ->
            {:ok, todo}

          [] ->
            query_error(:todo_not_found, %{id: id})

          values ->
            query_error(:ambiguous_todo_id, %{id: id, candidates: Enum.map(values, & &1.id)})
        end
    end
  end

  defp todo_map(todo, state) do
    checklist =
      state.checklist_items
      |> Map.values()
      |> Enum.filter(&(&1.task_id == todo.id and not &1.deleted))
      |> Enum.sort_by(&{&1.position || 0, downcase(&1.title), &1.id})
      |> Enum.map(&checklist_map/1)

    %{
      id: todo.id,
      entity_version: todo.entity_version,
      title: todo.title,
      notes: todo.notes,
      note_state: Atom.to_string(todo.note_state),
      type: Atom.to_string(todo.type),
      status: Atom.to_string(todo.status),
      schedule: atom_string(todo.schedule),
      evening: todo.evening,
      in_trash: todo.in_trash,
      position: todo.position,
      today_position: todo.today_position,
      area_ids: todo.area_ids,
      project_ids: todo.project_ids,
      heading_ids: todo.heading_ids,
      tag_ids: todo.tag_ids,
      checklist_items: checklist,
      recurrence_present: todo.recurrence_state_present,
      reminder_present: todo.reminder_present,
      created_at: iso8601(todo.created_at),
      modified_at: iso8601(todo.modified_at),
      expected_modified_at: iso8601(Todo.concurrency_at(todo)),
      stopped_at: iso8601(todo.stopped_at),
      scheduled_at: iso8601(todo.scheduled_at),
      today_reference_at: iso8601(todo.today_reference_at),
      deadline_at: iso8601(todo.deadline_at),
      state_complete: todo.state_complete,
      last_server_index: todo.last_server_index
    }
  end

  defp checklist_map(item) do
    %{
      id: item.id,
      title: item.title,
      status: Atom.to_string(item.status),
      stopped_at: iso8601(item.stopped_at),
      position: item.position,
      created_at: iso8601(item.created_at),
      modified_at: iso8601(item.modified_at),
      state_complete: item.state_complete,
      last_server_index: item.last_server_index
    }
  end

  defp reference_map(%{parent_ids: parent_ids} = tag) do
    %{
      id: tag.id,
      entity_version: tag.entity_version,
      title: tag.title,
      shortcut: tag.shortcut,
      parent_ids: parent_ids,
      position: tag.position,
      state_complete: tag.state_complete,
      last_server_index: tag.last_server_index
    }
  end

  defp reference_map(area) do
    %{
      id: area.id,
      entity_version: area.entity_version,
      title: area.title,
      tag_ids: area.tag_ids,
      position: area.position,
      state_complete: area.state_complete,
      last_server_index: area.last_server_index
    }
  end

  defp list_references(state, key, loader) do
    values = loader.() |> Enum.sort_by(&{Map.get(&1, :position) || 0, downcase(&1.title), &1.id})
    {:ok, %{key => values, count: length(values), freshness: freshness(state)}}
  end

  defp freshness(state) do
    %{
      source: "provider",
      provider_head: state.provider_head,
      state_complete: state.write_safe?,
      issue_count: length(state.issues)
    }
  end

  defp member(value, allowed, field) do
    if value in allowed,
      do: {:ok, value},
      else: query_error(:invalid_filter, %{field: field, value: value})
  end

  defp date(nil, _field), do: {:ok, nil}

  defp date(value, field) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> {:ok, date}
      {:error, _reason} -> query_error(:invalid_date_filter, %{field: field})
    end
  end

  defp date(_value, field), do: query_error(:invalid_date_filter, %{field: field})

  defp ordered_range(nil, _to, _field), do: :ok
  defp ordered_range(_from, nil, _field), do: :ok

  defp ordered_range(from, to, field) do
    if Date.compare(from, to) in [:lt, :eq],
      do: :ok,
      else: query_error(:invalid_date_range, %{field: field})
  end

  defp normalize_query(nil), do: nil
  defp normalize_query(value), do: value |> String.trim() |> String.downcase()
  defp downcase(value) when is_binary(value), do: String.downcase(value)
  defp downcase(_value), do: ""
  defp date_value(%DateTime{} = value), do: DateTime.to_date(value)
  defp date_value(_value), do: ~D[9999-12-31]
  defp iso8601(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp iso8601(_value), do: nil
  defp atom_string(value) when is_atom(value), do: Atom.to_string(value)
  defp atom_string(_value), do: nil
  defp query_error(reason, details), do: Protocol.error(reason, details)
end
