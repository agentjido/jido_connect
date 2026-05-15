defmodule Jido.Connect.Google.SearchConsole.CatalogPacks do
  @moduledoc "Curated catalog packs for common Google Search Console tool surfaces."

  alias Jido.Connect.Catalog.Pack

  @reader_tools [
    "google.search_console.search_analytics.query",
    "google.search_console.site.list",
    "google.search_console.sitemap.list",
    "google.search_console.url_inspection.inspect"
  ]

  @seo_tools @reader_tools ++
               [
                 "google.search_console.site.add",
                 "google.search_console.sitemap.submit"
               ]

  @doc "Returns all built-in Google Search Console catalog packs."
  def all, do: [reader(), seo()]

  @doc "Read-only Search Console pack for analytics, site listing, sitemap listing, and URL inspection."
  def reader do
    Pack.new!(%{
      id: :google_search_console_reader,
      label: "Google Search Console reader",
      description:
        "Query search analytics, list sites and sitemaps, and inspect URLs without mutation tools.",
      filters: %{provider: :google_search_console},
      allowed_tools: @reader_tools,
      metadata: %{package: :jido_connect_google_search_console, risk: :read}
    })
  end

  @doc "SEO pack with read tools plus site and sitemap management actions."
  def seo do
    Pack.new!(%{
      id: :google_search_console_seo,
      label: "Google Search Console SEO",
      description:
        "Full Search Console access: analytics, URL inspection, and site and sitemap management.",
      filters: %{provider: :google_search_console},
      allowed_tools: @seo_tools,
      metadata: %{package: :jido_connect_google_search_console, risk: :write}
    })
  end
end
