defmodule Jido.Connect.MicrosoftOnedrive.CatalogPacks do
  @moduledoc "Curated catalog packs for common Microsoft OneDrive tool surfaces."

  alias Jido.Connect.Catalog.Pack

  @metadata_tools [
    "microsoft.onedrive.items.list",
    "microsoft.onedrive.drive.get",
    "microsoft.onedrive.drives.list",
    "microsoft.onedrive.items.search",
    "microsoft.onedrive.items.delta"
  ]

  @triage_tools @metadata_tools ++
                  [
                    "microsoft.onedrive.item.get",
                    "microsoft.onedrive.item.download"
                  ]

  @write_tools @triage_tools ++
                 [
                   "microsoft.onedrive.item.create",
                   "microsoft.onedrive.item.update",
                   "microsoft.onedrive.item.upload"
                 ]

  @destructive_tools @write_tools ++
                       [
                         "microsoft.onedrive.item.delete"
                       ]

  @doc "Returns all built-in Microsoft OneDrive catalog packs."
  def all, do: [metadata(), triage(), write(), destructive()]

  @doc "Read-only Microsoft OneDrive metadata pack."
  def metadata do
    Pack.new!(%{
      id: :microsoft_onedrive_metadata,
      label: "Microsoft OneDrive metadata",
      description: "Read Microsoft OneDrive item list and drive metadata without mutation tools.",
      filters: %{provider: :microsoft_onedrive},
      allowed_tools: @metadata_tools,
      metadata: %{package: :jido_connect_microsoft_onedrive, risk: :read}
    })
  end

  @doc "Microsoft OneDrive triage pack for reading item details."
  def triage do
    Pack.new!(%{
      id: :microsoft_onedrive_triage,
      label: "Microsoft OneDrive triage",
      description:
        "Read Microsoft OneDrive items and drive details. Excludes item mutation and delete tools.",
      filters: %{provider: :microsoft_onedrive},
      allowed_tools: @triage_tools,
      metadata: %{
        package: :jido_connect_microsoft_onedrive,
        excludes: [
          "microsoft.onedrive.item.create",
          "microsoft.onedrive.item.update",
          "microsoft.onedrive.item.upload",
          "microsoft.onedrive.item.delete"
        ]
      }
    })
  end

  @doc "Microsoft OneDrive write pack for item create, update, and upload workflows."
  def write do
    Pack.new!(%{
      id: :microsoft_onedrive_write,
      label: "Microsoft OneDrive write",
      description:
        "Read Microsoft OneDrive metadata, create or update items, and upload files. Excludes delete tools.",
      filters: %{provider: :microsoft_onedrive},
      allowed_tools: @write_tools,
      metadata: %{
        package: :jido_connect_microsoft_onedrive,
        excludes: [
          "microsoft.onedrive.item.delete"
        ]
      }
    })
  end

  @doc "Microsoft OneDrive destructive pack for explicit item delete workflows."
  def destructive do
    Pack.new!(%{
      id: :microsoft_onedrive_destructive,
      label: "Microsoft OneDrive destructive",
      description: "Full Microsoft OneDrive access including item delete operations.",
      filters: %{provider: :microsoft_onedrive},
      allowed_tools: @destructive_tools,
      metadata: %{package: :jido_connect_microsoft_onedrive, risk: :destructive}
    })
  end
end
