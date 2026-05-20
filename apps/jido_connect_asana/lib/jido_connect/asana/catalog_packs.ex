defmodule Jido.Connect.Asana.CatalogPacks do
  @moduledoc """
  Curated catalog packs for common Asana tool surfaces.

  Packs are storage-free catalog filters that hosts pass to the catalog
  boundary to scope tool discovery and invocation.

  ## Packs

  | Pack | Risk | Tools |
  |------|------|-------|
  | `:asana_reader` | read | read-only queries |
  | `:asana_editor` | write | reader + mutations |

  Triggers are subscribed to independently and are not listed in packs.
  """

  alias Jido.Connect.Catalog.Pack

  @reader_tools [
    "asana.workspace.list",
    "asana.project.list",
    "asana.task.list",
    "asana.task.get",
    "asana.task.search",
    "asana.story.list",
    "asana.user.get",
    "asana.user.list"
  ]

  @write_tools [
    "asana.task.create",
    "asana.task.update",
    "asana.task.complete",
    "asana.task.uncomplete",
    "asana.task.add_project",
    "asana.task.remove_project",
    "asana.task.add_tag",
    "asana.task.remove_tag",
    "asana.story.create"
  ]

  @editor_tools @reader_tools ++ @write_tools

  @doc "Returns all built-in Asana catalog packs."
  def all, do: [reader(), editor()]

  @doc "Read-only Asana pack."
  def reader do
    Pack.new!(%{
      id: :asana_reader,
      label: "Asana reader",
      description: "Read Asana workspaces, projects, and tasks without mutation tools.",
      filters: %{provider: :asana},
      allowed_tools: @reader_tools,
      metadata: %{package: :jido_connect_asana, risk: :read}
    })
  end

  @doc "Asana editor pack for read and write tools."
  def editor do
    Pack.new!(%{
      id: :asana_editor,
      label: "Asana editor",
      description: "Read and write Asana workspaces, projects, and tasks.",
      filters: %{provider: :asana},
      allowed_tools: @editor_tools,
      metadata: %{package: :jido_connect_asana, risk: :write}
    })
  end
end
