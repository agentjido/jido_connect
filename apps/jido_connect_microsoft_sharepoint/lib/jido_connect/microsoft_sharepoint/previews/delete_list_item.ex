defmodule Jido.Connect.MicrosoftSharepoint.Previews.DeleteListItem do
  @moduledoc false

  @behaviour Jido.Connect.ActionPreview

  @impl true
  def preview(input, _context) do
    %{
      site_id: Map.get(input, :site_id),
      list_id: Map.get(input, :list_id),
      item_id: Map.get(input, :item_id),
      expected_version: Map.get(input, :etag)
    }
  end
end
