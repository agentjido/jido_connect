defmodule Jido.Connect.Trello.CatalogPacks do
  @moduledoc "Curated Trello reader, editor, and destructive packs."

  alias Jido.Connect.Catalog.Pack

  @reader_tools [
    "trello.board.get",
    "trello.list.list",
    "trello.list.get",
    "trello.label.list",
    "trello.card.list",
    "trello.card.get",
    "trello.card.search",
    "trello.checklist.list"
  ]

  @destructive_tools ["trello.list.archive", "trello.card.archive"]

  @editor_tools @reader_tools ++
                  [
                    "trello.list.create",
                    "trello.list.update",
                    "trello.list.move",
                    "trello.card.create",
                    "trello.card.update",
                    "trello.card.move",
                    "trello.card.complete",
                    "trello.card.label.attach",
                    "trello.card.label.detach",
                    "trello.checklist.create",
                    "trello.checklist.update",
                    "trello.checklist.item.create",
                    "trello.checklist.item.update"
                  ]

  def all, do: [reader(), editor(), destructive()]

  def reader do
    Pack.new!(%{
      id: :trello_reader,
      label: "Trello reader",
      description: "Read only the reviewed board-bound Trello resources.",
      filters: %{provider: :trello},
      allowed_tools: @reader_tools,
      metadata: %{package: :jido_connect_trello, risk: :read}
    })
  end

  def editor do
    Pack.new!(%{
      id: :trello_editor,
      label: "Trello editor",
      description: "Read and edit reviewed Trello resources without archive actions.",
      filters: %{provider: :trello},
      allowed_tools: @editor_tools,
      metadata: %{package: :jido_connect_trello, risk: :write}
    })
  end

  def destructive do
    Pack.new!(%{
      id: :trello_destructive,
      label: "Trello destructive operations",
      description: "Archive one reviewed Trello list or card.",
      filters: %{provider: :trello},
      allowed_tools: @destructive_tools,
      metadata: %{package: :jido_connect_trello, risk: :destructive}
    })
  end
end
