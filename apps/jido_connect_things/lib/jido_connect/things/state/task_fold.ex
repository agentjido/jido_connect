defmodule Jido.Connect.Things.State.TaskFold do
  @moduledoc false

  alias Jido.Connect.Things.{Todo, State.Note, State.Value}

  @known_fields ~w(
    tp sr dds rt rmd ss tr dl icp st ar tt do lai tir tg agr ix cd lt icc md ti dd ato nt
    icsd pr rp acrd sp sb rr xx
  )

  @statuses %{0 => :open, 2 => :canceled, 3 => :completed}
  @schedules %{0 => :inbox, 1 => :anytime, 2 => :someday}
  @types %{0 => :task, 1 => :project, 2 => :heading}

  def apply(current, entity, action, payload, server_index) when action in [0, 1] do
    base = current || new(entity)
    attrs = Map.from_struct(base)
    state = {attrs, []}

    state = Value.field(state, payload, "tt", :title, &Value.string/1)
    state = Value.field(state, payload, "ss", :status, Value.enum(@statuses))
    state = Value.field(state, payload, "st", :schedule, Value.enum(@schedules), clear: nil)
    state = Value.field(state, payload, "tp", :type, Value.enum(@types))
    state = Value.field(state, payload, "ix", :position, &Value.integer/1, clear: nil)
    state = Value.field(state, payload, "ti", :today_position, &Value.integer/1, clear: nil)
    state = Value.field(state, payload, "tr", :in_trash, &Value.boolean/1, clear: false)
    state = Value.field(state, payload, "sb", :evening, &Value.evening/1, clear: false)
    state = Value.field(state, payload, "ar", :area_ids, &Value.identifiers/1, clear: [])
    state = Value.field(state, payload, "pr", :project_ids, &Value.identifiers/1, clear: [])
    state = Value.field(state, payload, "agr", :heading_ids, &Value.identifiers/1, clear: [])
    state = Value.field(state, payload, "tg", :tag_ids, &Value.identifiers/1, clear: [])

    state =
      Value.field(state, payload, "rt", :recurrence_template_ids, &Value.identifiers/1, clear: [])

    state = Value.field(state, payload, "icp", :recurrence_paused, &Value.boolean/1, clear: false)
    state = Value.field(state, payload, "rr", :recurrence_rule, &Value.any/1, clear: nil)
    state = Value.field(state, payload, "ato", :alarm_time_offset, &Value.integer/1, clear: nil)
    state = datetime_fields(state, payload)
    {attrs, issues} = note_field(state, payload)

    unknown = Map.drop(payload, @known_fields)

    issues =
      if map_size(unknown) == 0, do: issues, else: [Value.issue(:unknown, :task_fields) | issues]

    attrs =
      attrs
      |> Map.put(:entity_version, entity)
      |> Map.put(:deleted, if(action == 0, do: false, else: attrs.deleted))
      |> Map.put(:last_server_index, server_index)
      |> Map.put(:unknown_fields, Map.merge(attrs.unknown_fields, unknown))
      |> put_recurrence_state(payload)
      |> put_reminder_state(payload)
      |> Map.put(:state_complete, attrs.state_complete and issues == [])

    case Todo.new(attrs) do
      {:ok, todo} -> {:ok, todo, Enum.reverse(issues)}
      {:error, _reason} -> {:error, Value.issue(:task, :invalid_materialized_state)}
    end
  end

  defp new(entity) do
    Todo.new!(%{
      id: "1111111111111111",
      entity_version: entity,
      status: :open,
      schedule: :anytime,
      type: :task
    })
  end

  def with_id(%Todo{} = todo, id), do: %{todo | id: id}

  defp datetime_fields(state, payload) do
    state
    |> Value.field(payload, "cd", :created_at, &Value.timestamp/1)
    |> Value.field(payload, "md", :modified_at, &Value.timestamp/1)
    |> Value.field(payload, "sp", :stopped_at, &Value.timestamp/1, clear: nil)
    |> Value.field(payload, "sr", :scheduled_at, &Value.timestamp/1, clear: nil)
    |> Value.field(payload, "tir", :today_reference_at, &Value.timestamp/1, clear: nil)
    |> Value.field(payload, "dd", :deadline_at, &Value.timestamp/1, clear: nil)
  end

  defp note_field({attrs, issues}, payload) do
    case Map.fetch(payload, "nt") do
      :error ->
        {attrs, issues}

      {:ok, note} ->
        {text, note_state, note_issues} = Note.apply(attrs.notes, attrs.note_state, note)

        {attrs |> Map.put(:notes, text) |> Map.put(:note_state, note_state),
         Enum.reverse(note_issues) ++ issues}
    end
  end

  defp put_recurrence_state(attrs, payload) do
    markers = update_markers(attrs.recurrence_marker_fields, payload, ["rp", "icsd", "dds"])

    present =
      attrs.recurrence_rule not in [nil, %{}] or attrs.recurrence_template_ids != [] or
        attrs.recurrence_paused or map_size(markers) > 0

    attrs
    |> Map.put(:recurrence_marker_fields, markers)
    |> Map.put(:recurrence_state_present, present)
  end

  defp put_reminder_state(attrs, payload) do
    markers = update_markers(attrs.reminder_marker_fields, payload, ["rmd", "lai", "acrd"])

    attrs
    |> Map.put(:reminder_marker_fields, markers)
    |> Map.put(:reminder_present, not is_nil(attrs.alarm_time_offset) or map_size(markers) > 0)
  end

  defp update_markers(current, payload, keys) do
    Enum.reduce(keys, current, fn key, markers ->
      if Map.has_key?(payload, key) do
        if Map.get(payload, key) in [nil, false, [], %{}] do
          Map.delete(markers, key)
        else
          Map.put(markers, key, true)
        end
      else
        markers
      end
    end)
  end
end
