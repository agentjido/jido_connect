defmodule Jido.Connect.Jira.Previews.CreateBoard do
  @moduledoc false
  @behaviour Jido.Connect.ActionPreview

  def preview(input, _context),
    do:
      Map.take(input, [:name, :type, :filter_id, :location, :project])
      |> Map.put(:operation, "create_board")
end
