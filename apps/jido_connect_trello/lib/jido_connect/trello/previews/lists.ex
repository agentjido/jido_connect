defmodule Jido.Connect.Trello.Previews.ListCreate do
  @moduledoc false
  @behaviour Jido.Connect.ActionPreview
  def preview(input, _context),
    do: Jido.Connect.Trello.Previews.Support.build("list.create", input, [:name, :position])
end

defmodule Jido.Connect.Trello.Previews.ListUpdate do
  @moduledoc false
  @behaviour Jido.Connect.ActionPreview
  def preview(input, _context),
    do: Jido.Connect.Trello.Previews.Support.build("list.update", input, [:id, :name])
end

defmodule Jido.Connect.Trello.Previews.ListMove do
  @moduledoc false
  @behaviour Jido.Connect.ActionPreview
  def preview(input, _context),
    do: Jido.Connect.Trello.Previews.Support.build("list.move", input, [:id, :position])
end

defmodule Jido.Connect.Trello.Previews.ListArchive do
  @moduledoc false
  @behaviour Jido.Connect.ActionPreview
  def preview(input, _context),
    do: Jido.Connect.Trello.Previews.Support.build("list.archive", input, [:id])
end
