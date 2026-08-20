defmodule Jido.Connect.Trello.Normalizer.Board do
  @moduledoc false

  alias Jido.Connect.Trello.Normalizer.Value

  def normalize!(board) when is_map(board) do
    %{
      id: Value.required_string!(board, "id", :board_id),
      objectId: Value.required_string!(board, "objectId", :board_object_id),
      shortId: Value.required_string!(board, "shortLink", :board_short_id),
      name: Value.required_string!(board, "name", :board_name),
      url: Value.required_string!(board, "url", :board_url),
      closed: Value.required_boolean!(board, "closed", :board_closed),
      description: Value.optional_string!(board, "description", :board_description),
      lastActivityAt: Value.optional_string!(board, "lastActivityAt", :board_activity)
    }
  end

  def normalize!(_board), do: Value.invalid!(:board)

  def labels_page!(%{"labels" => labels} = payload) when is_list(labels) do
    {Enum.map(labels, &label!/1), Value.cursor_page!(payload)}
  end

  def labels_page!(_payload), do: Value.invalid!(:labels_page)

  def label!(label) when is_map(label) do
    %{
      id: Value.required_string!(label, "id", :label_id),
      objectId: Value.optional_string!(label, "objectId", :label_object_id),
      name: Value.optional_string!(label, "name", :label_name),
      color: Value.optional_string!(label, "color", :label_color),
      uses: Value.optional_number!(label, "uses", :label_uses)
    }
  end

  def label!(_label), do: Value.invalid!(:label)
end
