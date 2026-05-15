defmodule Jido.Connect.Google.Docs.CatalogPacks do
  @moduledoc "Curated catalog packs for common Google Docs tool surfaces."

  alias Jido.Connect.Catalog.Pack

  @readonly_tools [
    "google.docs.document.get"
  ]

  @editor_tools @readonly_tools ++
                  [
                    "google.docs.document.create",
                    "google.docs.document.batch_update"
                  ]

  @doc "Returns all built-in Google Docs catalog packs."
  def all, do: [readonly(), editor()]

  @doc "Read-only Docs metadata and content pack."
  def readonly do
    Pack.new!(%{
      id: :google_docs_readonly,
      label: "Google Docs read-only",
      description: "Read Google Docs document metadata and content without mutation tools.",
      filters: %{provider: :google_docs},
      allowed_tools: @readonly_tools,
      metadata: %{package: :jido_connect_google_docs, risk: :read}
    })
  end

  @doc "Docs editor pack for document creation and batch updates."
  def editor do
    Pack.new!(%{
      id: :google_docs_editor,
      label: "Google Docs editor",
      description:
        "Read, create, and batch update Google Docs documents. Includes all mutation tools.",
      filters: %{provider: :google_docs},
      allowed_tools: @editor_tools,
      metadata: %{package: :jido_connect_google_docs, risk: :write}
    })
  end
end
