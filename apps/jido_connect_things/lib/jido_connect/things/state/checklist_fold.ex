defmodule Jido.Connect.Things.State.ChecklistFold do
  @moduledoc false

  alias Jido.Connect.Things.{ChecklistItem, State.Value}

  @known_fields ~w(cd md tt ss sp ix ts lt xx)
  @statuses %{0 => :open, 2 => :canceled, 3 => :completed}

  def apply(current, id, entity, action, payload, server_index) when action in [0, 1] do
    attrs = current |> Kernel.||(new(id, entity)) |> Map.from_struct()
    state = {attrs, []}
    state = Value.field(state, payload, "tt", :title, &Value.string/1)
    state = Value.field(state, payload, "ss", :status, Value.enum(@statuses))
    state = Value.field(state, payload, "ix", :position, &Value.integer/1, clear: nil)
    state = Value.field(state, payload, "cd", :created_at, &Value.timestamp/1)
    state = Value.field(state, payload, "md", :modified_at, &Value.timestamp/1)
    state = Value.field(state, payload, "sp", :stopped_at, &Value.timestamp/1, clear: nil)
    {attrs, issues} = task_relation(state, payload)
    unknown = Map.drop(payload, @known_fields)

    issues =
      if map_size(unknown) == 0,
        do: issues,
        else: [Value.issue(:unknown, :checklist_fields) | issues]

    attrs =
      attrs
      |> Map.put(:entity_version, entity)
      |> Map.put(:deleted, if(action == 0, do: false, else: attrs.deleted))
      |> Map.put(:last_server_index, server_index)
      |> Map.put(:unknown_fields, Map.merge(attrs.unknown_fields, unknown))
      |> Map.put(:state_complete, attrs.state_complete and issues == [])

    case ChecklistItem.new(attrs) do
      {:ok, item} -> {:ok, item, Enum.reverse(issues)}
      {:error, _reason} -> {:error, Value.issue(:checklist, :invalid_materialized_state)}
    end
  end

  defp new(id, entity) do
    ChecklistItem.new!(%{id: id, entity_version: entity})
  end

  defp task_relation({attrs, issues}, payload) do
    case Map.fetch(payload, "ts") do
      :error ->
        {attrs, issues}

      {:ok, nil} ->
        {Map.put(attrs, :task_id, nil), issues}

      {:ok, [task_id]} ->
        case Value.identifiers([task_id]) do
          {:ok, [task_id]} -> {Map.put(attrs, :task_id, task_id), issues}
          :error -> {attrs, [Value.issue("ts", :invalid_task_relation) | issues]}
        end

      {:ok, _value} ->
        {attrs, [Value.issue("ts", :invalid_task_relation) | issues]}
    end
  end
end
