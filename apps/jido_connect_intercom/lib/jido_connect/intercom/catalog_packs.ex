defmodule Jido.Connect.Intercom.CatalogPacks do
  @moduledoc """
  Curated catalog packs for common Intercom tool surfaces.

  Packs are storage-free catalog filters that hosts pass to the catalog
  boundary to scope tool discovery and invocation.

  ## Packs

  | Pack | Risk | Tools |
  |------|------|-------|
  | `:intercom_reader` | read | read-only queries |
  | `:intercom_editor` | write | reader + mutations |

  Triggers are subscribed to independently and are not listed in packs.

  Tool IDs will be populated when action fragments are added in subsequent
  waves.
  """

  alias Jido.Connect.Catalog.Pack

  @reader_tools []
  @write_tools []
  @editor_tools @reader_tools ++ @write_tools

  @doc "Returns all built-in Intercom catalog packs."
  def all, do: [reader(), editor()]

  @doc "Read-only Intercom pack."
  def reader do
    Pack.new!(%{
      id: :intercom_reader,
      label: "Intercom reader",
      description: "Read Intercom resources without mutation tools.",
      filters: %{provider: :intercom},
      allowed_tools: @reader_tools,
      metadata: %{package: :jido_connect_intercom, risk: :read}
    })
  end

  @doc "Intercom editor pack for read and write tools."
  def editor do
    Pack.new!(%{
      id: :intercom_editor,
      label: "Intercom editor",
      description: "Read and write Intercom resources.",
      filters: %{provider: :intercom},
      allowed_tools: @editor_tools,
      metadata: %{package: :jido_connect_intercom, risk: :write}
    })
  end
end
