defmodule Jido.Connect.Confluence.Previews.CreatePage do
  @moduledoc false
  @behaviour Jido.Connect.ActionPreview

  alias Jido.Connect.Confluence.Previews.Support

  def preview(input, _context) do
    %{
      operation: "create_page",
      title: Map.get(input, :title),
      space_key: Map.get(input, :space_key),
      parent_id: Map.get(input, :parent_id),
      markdown_characters: Support.character_count(Map.get(input, :markdown))
    }
  end
end

defmodule Jido.Connect.Confluence.Previews.UpdatePage do
  @moduledoc false
  @behaviour Jido.Connect.ActionPreview

  alias Jido.Connect.Confluence.Previews.Support

  def preview(input, _context) do
    %{
      operation: "update_page",
      page_id: Map.get(input, :id),
      space_key: Map.get(input, :space_key),
      last_pushed_version: Map.get(input, :last_pushed_version),
      force: Map.get(input, :force, false),
      title: Map.get(input, :title),
      version_message: Map.get(input, :version_message),
      markdown_characters: Support.character_count(Map.get(input, :markdown))
    }
  end
end

defmodule Jido.Connect.Confluence.Previews.DeletePage do
  @moduledoc false
  @behaviour Jido.Connect.ActionPreview

  def preview(input, _context),
    do: %{operation: "delete_page", page_id: Map.get(input, :id)}
end
