defmodule Jido.Connect.Trello.Normalizer.List do
  @moduledoc false

  alias Jido.Connect.Trello.Normalizer.{Card, Value}

  def normalize!(list) when is_map(list) do
    %{
      id: Value.required_string!(list, "id", :list_id),
      objectId: Value.optional_string!(list, "objectId", :list_object_id),
      name: Value.required_string!(list, "name", :list_name),
      position: Value.optional_number!(list, "position", :list_position),
      cards: Value.embedded!(list["cards"], &Card.summary!/1, :list_cards)
    }
  end

  def normalize!(_list), do: Value.invalid!(:list)

  def page!(%{"lists" => lists, "pageInfo" => page}) when is_list(lists) and is_map(page) do
    page_info = %{
      hasNextPage: Value.required_boolean!(page, "hasNextPage", :list_page_state),
      endCursor: Value.optional_string!(page, "endCursor", :list_page_cursor)
    }

    {Enum.map(lists, &normalize!/1), page_info}
  end

  def page!(_payload), do: Value.invalid!(:lists_page)
end
