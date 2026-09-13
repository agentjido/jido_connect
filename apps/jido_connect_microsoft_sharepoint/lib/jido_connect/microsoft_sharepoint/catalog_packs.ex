defmodule Jido.Connect.MicrosoftSharepoint.CatalogPacks do
  @moduledoc "Curated catalog packs for Microsoft SharePoint tools."

  alias Jido.Connect.Catalog.Pack

  @metadata_tools [
    "microsoft.sharepoint.site.resolve",
    "microsoft.sharepoint.site.get",
    "microsoft.sharepoint.sites.search",
    "microsoft.sharepoint.lists.list",
    "microsoft.sharepoint.list.get",
    "microsoft.sharepoint.list.columns.list",
    "microsoft.sharepoint.libraries.list"
  ]

  @read_tools @metadata_tools ++
                [
                  "microsoft.sharepoint.list.items.list",
                  "microsoft.sharepoint.list.item.get",
                  "microsoft.sharepoint.list.items.delta",
                  "microsoft.sharepoint.library.items.list",
                  "microsoft.sharepoint.library.item.get",
                  "microsoft.sharepoint.library.items.search",
                  "microsoft.sharepoint.library.item.download",
                  "microsoft.sharepoint.library.items.delta"
                ]

  @sync_tools [
    "microsoft.sharepoint.site.resolve",
    "microsoft.sharepoint.site.get",
    "microsoft.sharepoint.lists.list",
    "microsoft.sharepoint.list.get",
    "microsoft.sharepoint.list.columns.list",
    "microsoft.sharepoint.list.items.delta",
    "microsoft.sharepoint.libraries.list",
    "microsoft.sharepoint.library.items.delta"
  ]

  @write_tools @read_tools ++
                 [
                   "microsoft.sharepoint.list.item.create",
                   "microsoft.sharepoint.list.item.update",
                   "microsoft.sharepoint.library.folder.create",
                   "microsoft.sharepoint.library.item.upload",
                   "microsoft.sharepoint.library.item.update"
                 ]

  @destructive_tools @write_tools ++
                       [
                         "microsoft.sharepoint.list.item.delete",
                         "microsoft.sharepoint.library.item.delete"
                       ]

  @doc "Returns all built-in SharePoint catalog packs."
  def all, do: [metadata(), read(), sync(), write(), destructive()]

  @doc "Read-only SharePoint site, list, column, and library metadata pack."
  def metadata do
    pack(
      :microsoft_sharepoint_metadata,
      "SharePoint metadata",
      "Read SharePoint site, list, column, and library metadata.",
      @metadata_tools,
      %{risk: :read}
    )
  end

  @doc "Read-only SharePoint content pack."
  def read do
    pack(
      :microsoft_sharepoint_read,
      "SharePoint read",
      "Read SharePoint metadata, list items, and document library content.",
      @read_tools,
      %{risk: :read}
    )
  end

  @doc "Read-only SharePoint incremental synchronization pack."
  def sync do
    pack(
      :microsoft_sharepoint_sync,
      "SharePoint sync",
      "Read SharePoint list and document library delta feeds.",
      @sync_tools,
      %{risk: :read, purpose: :sync}
    )
  end

  @doc "SharePoint write pack without delete tools."
  def write do
    pack(
      :microsoft_sharepoint_write,
      "SharePoint write",
      "Read and change SharePoint list items and document libraries without delete tools.",
      @write_tools,
      %{
        excludes: [
          "microsoft.sharepoint.list.item.delete",
          "microsoft.sharepoint.library.item.delete"
        ]
      }
    )
  end

  @doc "Full SharePoint pack with explicit delete tools."
  def destructive do
    pack(
      :microsoft_sharepoint_destructive,
      "SharePoint destructive",
      "Use all SharePoint tools, including list item and document delete tools.",
      @destructive_tools,
      %{risk: :destructive}
    )
  end

  defp pack(id, label, description, allowed_tools, metadata) do
    Pack.new!(%{
      id: id,
      label: label,
      description: description,
      filters: %{provider: :microsoft_sharepoint},
      allowed_tools: allowed_tools,
      metadata: Map.put(metadata, :package, :jido_connect_microsoft_sharepoint)
    })
  end
end
