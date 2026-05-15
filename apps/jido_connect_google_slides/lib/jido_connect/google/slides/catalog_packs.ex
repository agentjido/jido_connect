defmodule Jido.Connect.Google.Slides.CatalogPacks do
  @moduledoc "Curated catalog packs for common Google Slides tool surfaces."

  alias Jido.Connect.Catalog.Pack

  @readonly_tools [
    "google.slides.presentation.get",
    "google.slides.presentation.page.get_thumbnail"
  ]

  @editor_tools @readonly_tools ++
                  ["google.slides.presentation.create", "google.slides.presentation.batch_update"]

  @doc "Returns all built-in Google Slides catalog packs."
  def all, do: [readonly(), editor()]

  @doc "Read-only Slides metadata and content pack."
  def readonly do
    Pack.new!(%{
      id: :google_slides_readonly,
      label: "Google Slides read-only",
      description: "Read Google Slides presentation metadata and content without mutation tools.",
      filters: %{provider: :google_slides},
      allowed_tools: @readonly_tools,
      metadata: %{package: :jido_connect_google_slides, risk: :read}
    })
  end

  @doc "Slides editor pack for presentation creation and updates."
  def editor do
    Pack.new!(%{
      id: :google_slides_editor,
      label: "Google Slides editor",
      description:
        "Read, create, and update Google Slides presentations. Includes all mutation tools.",
      filters: %{provider: :google_slides},
      allowed_tools: @editor_tools,
      metadata: %{package: :jido_connect_google_slides, risk: :write}
    })
  end
end
