defmodule Jido.Connect.MicrosoftSharepoint.Previews.DocumentLibraryWrite do
  @moduledoc false

  @behaviour Jido.Connect.ActionPreview

  @impl true
  def preview(input, _context) do
    %{
      drive_id: Map.get(input, :drive_id),
      parent_id: Map.get(input, :parent_id),
      item_id: Map.get(input, :item_id),
      name: Map.get(input, :name),
      expected_version: Map.get(input, :etag),
      content_size: content_size(Map.get(input, :content))
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp content_size(content) when is_binary(content), do: byte_size(content)
  defp content_size(_content), do: nil
end
