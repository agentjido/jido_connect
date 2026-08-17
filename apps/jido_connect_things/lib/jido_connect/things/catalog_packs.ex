defmodule Jido.Connect.Things.CatalogPacks do
  @moduledoc "Curated, storage-free catalog packs for the Things Cloud V1 surface."

  alias Jido.Connect.Catalog.Pack

  @reader_tools [
    "things.todo.list",
    "things.todo.get",
    "things.todo.search",
    "things.project.list",
    "things.heading.list",
    "things.area.list",
    "things.tag.list"
  ]
  @editor_tools @reader_tools ++
                  [
                    "things.todo.create",
                    "things.todo.update",
                    "things.todo.schedule",
                    "things.todo.deadline.set",
                    "things.todo.deadline.clear",
                    "things.todo.tags.set",
                    "things.todo.move",
                    "things.todo.complete",
                    "things.todo.cancel",
                    "things.todo.reopen",
                    "things.todo.trash",
                    "things.todo.restore"
                  ]

  def all, do: [reader(), editor()]

  def reader do
    Pack.new!(%{
      id: :things_inbox_reader,
      label: "Things Inbox reader",
      description: "List open Things Cloud Inbox to-dos without write tools.",
      filters: %{provider: :things},
      allowed_tools: @reader_tools,
      metadata: %{package: :jido_connect_things, risk: :read, storage: :host_owned}
    })
  end

  def editor do
    Pack.new!(%{
      id: :things_inbox_editor,
      label: "Things Inbox editor",
      description:
        "List, create, and update open Things Cloud Inbox to-dos through guarded writes.",
      filters: %{provider: :things},
      allowed_tools: @editor_tools,
      metadata: %{
        package: :jido_connect_things,
        risk: :external_write,
        storage: :host_owned,
        unofficial_api?: true
      }
    })
  end
end
