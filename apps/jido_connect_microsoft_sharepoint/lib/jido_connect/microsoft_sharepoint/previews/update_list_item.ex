defmodule Jido.Connect.MicrosoftSharepoint.Previews.UpdateListItem do
  @moduledoc false

  @behaviour Jido.Connect.ActionPreview

  @impl true
  def preview(input, _context) do
    fields = Map.get(input, :fields, %{})

    %{
      site_id: Map.get(input, :site_id),
      list_id: Map.get(input, :list_id),
      item_id: Map.get(input, :item_id),
      expected_version: Map.get(input, :etag),
      field_names: fields |> Map.keys() |> Enum.map(&to_string/1) |> Enum.sort(),
      field_count: map_size(fields)
    }
  end
end
