defmodule Jido.Connect.MicrosoftSharepoint.Previews.CreateListItem do
  @moduledoc false

  @behaviour Jido.Connect.ActionPreview

  @impl true
  def preview(input, _context) do
    fields = Map.get(input, :fields, %{})

    %{
      site_id: Map.get(input, :site_id),
      list_id: Map.get(input, :list_id),
      field_names: fields |> Map.keys() |> Enum.map(&to_string/1) |> Enum.sort(),
      field_count: map_size(fields)
    }
  end
end
