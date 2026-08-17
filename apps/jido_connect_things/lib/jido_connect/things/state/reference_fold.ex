defmodule Jido.Connect.Things.State.ReferenceFold do
  @moduledoc false

  alias Jido.Connect.Things.{Area, Tag, State.Value}

  @area_fields ~w(tt tg ix xx md)
  @tag_fields ~w(tt ix sh pn xx md)

  def area(current, id, entity, action, payload, server_index) when action in [0, 1] do
    attrs =
      current |> Kernel.||(Area.new!(%{id: id, entity_version: entity})) |> Map.from_struct()

    state = {attrs, []}
    state = Value.field(state, payload, "tt", :title, &Value.string/1)
    state = Value.field(state, payload, "ix", :position, &Value.integer/1, clear: nil)
    {attrs, issues} = Value.field(state, payload, "tg", :tag_ids, &Value.identifiers/1, clear: [])
    finish(Area, attrs, issues, payload, @area_fields, entity, action, server_index)
  end

  def tag(current, id, entity, action, payload, server_index) when action in [0, 1] do
    attrs = current |> Kernel.||(Tag.new!(%{id: id, entity_version: entity})) |> Map.from_struct()
    state = {attrs, []}
    state = Value.field(state, payload, "tt", :title, &Value.string/1)
    state = Value.field(state, payload, "ix", :position, &Value.integer/1, clear: nil)
    state = Value.field(state, payload, "sh", :shortcut, &Value.string/1, clear: nil)

    {attrs, issues} =
      Value.field(state, payload, "pn", :parent_ids, &Value.identifiers/1, clear: [])

    finish(Tag, attrs, issues, payload, @tag_fields, entity, action, server_index)
  end

  defp finish(module, attrs, issues, payload, known, entity, action, server_index) do
    unknown = Map.drop(payload, known)

    issues =
      if map_size(unknown) == 0,
        do: issues,
        else: [Value.issue(:unknown, :reference_fields) | issues]

    attrs =
      attrs
      |> Map.put(:entity_version, entity)
      |> Map.put(:deleted, if(action == 0, do: false, else: attrs.deleted))
      |> Map.put(:last_server_index, server_index)
      |> Map.put(:unknown_fields, Map.merge(attrs.unknown_fields, unknown))
      |> Map.put(:state_complete, attrs.state_complete and issues == [])

    case module.new(attrs) do
      {:ok, value} -> {:ok, value, Enum.reverse(issues)}
      {:error, _reason} -> {:error, Value.issue(:reference, :invalid_materialized_state)}
    end
  end
end
