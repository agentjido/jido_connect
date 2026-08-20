defmodule Jido.Connect.Trello.Previews.CardCreate do
  @moduledoc false
  @behaviour Jido.Connect.ActionPreview

  def preview(input, _context) do
    Jido.Connect.Trello.Previews.Support.build("card.create", input, [
      :list_id,
      :name,
      {:characters, :description, :description_characters},
      :due,
      :position
    ])
  end
end

defmodule Jido.Connect.Trello.Previews.CardUpdate do
  @moduledoc false
  @behaviour Jido.Connect.ActionPreview

  def preview(input, _context) do
    Jido.Connect.Trello.Previews.Support.build("card.update", input, [
      :card_id,
      :name,
      {:characters, :description, :description_characters},
      :due
    ])
  end
end

defmodule Jido.Connect.Trello.Previews.CardMove do
  @moduledoc false
  @behaviour Jido.Connect.ActionPreview
  def preview(input, _context),
    do:
      Jido.Connect.Trello.Previews.Support.build("card.move", input, [
        :card_id,
        :list_id,
        :position
      ])
end

defmodule Jido.Connect.Trello.Previews.CardComplete do
  @moduledoc false
  @behaviour Jido.Connect.ActionPreview
  def preview(input, _context),
    do: Jido.Connect.Trello.Previews.Support.build("card.complete", input, [:card_id])
end

defmodule Jido.Connect.Trello.Previews.CardArchive do
  @moduledoc false
  @behaviour Jido.Connect.ActionPreview
  def preview(input, _context),
    do: Jido.Connect.Trello.Previews.Support.build("card.archive", input, [:card_id])
end

defmodule Jido.Connect.Trello.Previews.CardLabelAttach do
  @moduledoc false
  @behaviour Jido.Connect.ActionPreview
  def preview(input, _context),
    do:
      Jido.Connect.Trello.Previews.Support.build("card.label.attach", input, [:card_id, :label_id])
end

defmodule Jido.Connect.Trello.Previews.CardLabelDetach do
  @moduledoc false
  @behaviour Jido.Connect.ActionPreview
  def preview(input, _context),
    do:
      Jido.Connect.Trello.Previews.Support.build("card.label.detach", input, [:card_id, :label_id])
end
