defmodule Jido.Connect.Zendesk.CatalogPacks do
  @moduledoc """
  Curated catalog packs for common Zendesk tool surfaces.

  Packs are storage-free catalog filters that hosts pass to the catalog
  boundary to scope tool discovery and invocation.

  ## Packs

  | Pack | Risk | Tools |
  |------|------|-------|
  | `:zendesk_reader` | read | read-only queries |
  | `:zendesk_editor` | write | reader + mutations |

  Triggers are subscribed to independently and are not listed in packs.

  Tool IDs will be populated when action fragments are added in subsequent
  waves.
  """

  alias Jido.Connect.Catalog.Pack

  @reader_tools [
    "zendesk.ticket.list",
    "zendesk.ticket.search",
    "zendesk.ticket.get",
    "zendesk.ticket.comment.list",
    "zendesk.user.list",
    "zendesk.organization.list"
  ]

  @write_tools [
    "zendesk.ticket.create",
    "zendesk.ticket.update",
    "zendesk.ticket.comment.add"
  ]

  @editor_tools @reader_tools ++ @write_tools

  @doc "Returns all built-in Zendesk catalog packs."
  def all, do: [reader(), editor()]

  @doc "Read-only Zendesk pack."
  def reader do
    Pack.new!(%{
      id: :zendesk_reader,
      label: "Zendesk reader",
      description: "Read Zendesk resources without mutation tools.",
      filters: %{provider: :zendesk},
      allowed_tools: @reader_tools,
      metadata: %{package: :jido_connect_zendesk, risk: :read}
    })
  end

  @doc "Zendesk editor pack for read and write tools."
  def editor do
    Pack.new!(%{
      id: :zendesk_editor,
      label: "Zendesk editor",
      description: "Read and write Zendesk resources.",
      filters: %{provider: :zendesk},
      allowed_tools: @editor_tools,
      metadata: %{package: :jido_connect_zendesk, risk: :write}
    })
  end
end
