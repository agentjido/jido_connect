defmodule Jido.Connect.Confluence.CatalogPacks do
  @moduledoc "Curated Confluence reader, editor, and destructive catalog packs."

  alias Jido.Connect.Catalog.Pack

  @reader_tools [
    "confluence.space.get",
    "confluence.page.list",
    "confluence.page.get"
  ]

  @editor_tools @reader_tools ++ ["confluence.page.create", "confluence.page.update"]
  @destructive_tools ["confluence.page.delete"]

  def all, do: [reader(), editor(), destructive()]

  def reader do
    Pack.new!(%{
      id: :confluence_reader,
      label: "Confluence reader",
      description: "Read reviewed Confluence spaces and pages without mutation tools.",
      filters: %{provider: :confluence},
      allowed_tools: @reader_tools,
      metadata: %{package: :jido_connect_confluence, risk: :read}
    })
  end

  def editor do
    Pack.new!(%{
      id: :confluence_editor,
      label: "Confluence editor",
      description: "Read, create, and update Confluence pages without delete access.",
      filters: %{provider: :confluence},
      allowed_tools: @editor_tools,
      metadata: %{package: :jido_connect_confluence, risk: :write}
    })
  end

  def destructive do
    Pack.new!(%{
      id: :confluence_destructive,
      label: "Confluence destructive operations",
      description: "Move a reviewed Confluence page to the trash.",
      filters: %{provider: :confluence},
      allowed_tools: @destructive_tools,
      metadata: %{package: :jido_connect_confluence, risk: :destructive}
    })
  end
end
