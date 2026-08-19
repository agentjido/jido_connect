defmodule Jido.Connect.Trello.Normalizer.Checklist do
  @moduledoc false

  alias Jido.Connect.Trello.Normalizer.Value

  def normalize!(checklist) when is_map(checklist) do
    items = checklist["items"] || checklist["checkItems"]

    %{
      id: Value.required_string!(checklist, "id", :checklist_id),
      objectId: Value.optional_string!(checklist, "objectId", :checklist_object_id),
      name: Value.required_string!(checklist, "name", :checklist_name),
      position: Value.optional_number!(checklist, "position", :checklist_position),
      items: Value.embedded!(items, &item!/1, :checklist_items)
    }
  end

  def normalize!(_checklist), do: Value.invalid!(:checklist)

  def item!(item) when is_map(item) do
    %{
      id: Value.required_string!(item, "id", :checklist_item_id),
      name: Value.required_string!(item, "name", :checklist_item_name),
      checked: checked!(item),
      position: Value.optional_number!(item, "position", :checklist_item_position)
    }
  end

  def item!(_item), do: Value.invalid!(:checklist_item)

  def page!(%{"checklists" => checklists} = payload) when is_list(checklists) do
    {Enum.map(checklists, &normalize!/1), Value.cursor_page!(payload)}
  end

  def page!(_payload), do: Value.invalid!(:checklists_page)

  defp checked!(%{"checked" => checked}) when is_boolean(checked), do: checked
  defp checked!(%{"state" => "complete"}), do: true
  defp checked!(%{"state" => "incomplete"}), do: false
  defp checked!(_item), do: Value.invalid!(:checklist_item_state)
end
