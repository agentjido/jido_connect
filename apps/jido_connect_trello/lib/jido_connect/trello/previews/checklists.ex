defmodule Jido.Connect.Trello.Previews.ChecklistCreate do
  @moduledoc false
  @behaviour Jido.Connect.ActionPreview
  def preview(input, _context),
    do:
      Jido.Connect.Trello.Previews.Support.build("checklist.create", input, [
        :card_id,
        :name,
        :position
      ])
end

defmodule Jido.Connect.Trello.Previews.ChecklistUpdate do
  @moduledoc false
  @behaviour Jido.Connect.ActionPreview
  def preview(input, _context),
    do:
      Jido.Connect.Trello.Previews.Support.build("checklist.update", input, [
        :card_id,
        :checklist_id,
        :name,
        :position
      ])
end

defmodule Jido.Connect.Trello.Previews.ChecklistItemCreate do
  @moduledoc false
  @behaviour Jido.Connect.ActionPreview

  def preview(input, _context) do
    Jido.Connect.Trello.Previews.Support.build("checklist.item.create", input, [
      :card_id,
      :checklist_id,
      {:characters, :text, :text_characters},
      :position
    ])
  end
end

defmodule Jido.Connect.Trello.Previews.ChecklistItemUpdate do
  @moduledoc false
  @behaviour Jido.Connect.ActionPreview

  def preview(input, _context) do
    Jido.Connect.Trello.Previews.Support.build("checklist.item.update", input, [
      :card_id,
      :checklist_id,
      :item_id,
      {:characters, :text, :text_characters},
      :checked,
      :position
    ])
  end
end
