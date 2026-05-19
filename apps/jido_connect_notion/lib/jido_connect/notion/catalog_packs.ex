defmodule Jido.Connect.Notion.CatalogPacks do
  @moduledoc """
  Curated catalog packs for common Notion tool surfaces.

  Packs are storage-free catalog filters that hosts pass to the catalog
  boundary to scope tool discovery and invocation.

  ## Packs

  | Pack | Risk | Tools |
  |------|------|-------|
  | `:notion_reader` | read | read-only queries |
  | `:notion_editor` | write | reader + mutations |

  Triggers are subscribed to independently and are not listed in packs.

  Tool IDs will be populated when action fragments are added in subsequent
  waves.
  """

  alias Jido.Connect.Catalog.Pack

  @reader_tools [
    "notion.search",
    "notion.page.get",
    "notion.database.get",
    "notion.database.query",
    "notion.block.get",
    "notion.block.list_children",
    "notion.comment.list"
  ]
  @write_tools [
    "notion.page.create",
    "notion.page.update",
    "notion.block.append_children",
    "notion.block.update",
    "notion.block.archive",
    "notion.comment.create"
  ]
  @editor_tools @reader_tools ++ @write_tools

  @doc "Returns all built-in Notion catalog packs."
  def all, do: [reader(), editor()]

  @doc "Read-only Notion pack."
  def reader do
    Pack.new!(%{
      id: :notion_reader,
      label: "Notion reader",
      description: "Read Notion pages, databases, and content without mutation tools.",
      filters: %{provider: :notion},
      allowed_tools: @reader_tools,
      metadata: %{package: :jido_connect_notion, risk: :read}
    })
  end

  @doc "Notion editor pack for read and write tools."
  def editor do
    Pack.new!(%{
      id: :notion_editor,
      label: "Notion editor",
      description: "Read and write Notion pages, databases, and content.",
      filters: %{provider: :notion},
      allowed_tools: @editor_tools,
      metadata: %{package: :jido_connect_notion, risk: :write}
    })
  end
end
