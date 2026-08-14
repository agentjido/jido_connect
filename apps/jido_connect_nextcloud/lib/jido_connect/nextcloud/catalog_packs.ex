defmodule Jido.Connect.Nextcloud.CatalogPacks do
  @moduledoc "Curated catalog packs for common Nextcloud tool surfaces."

  alias Jido.Connect.Catalog.Pack

  @files_readonly_tools [
    "nextcloud.files.list",
    "nextcloud.file.get",
    "nextcloud.files.search",
    "nextcloud.file.download",
    "nextcloud.office.capabilities.get"
  ]

  @files_write_tools @files_readonly_tools ++
                       [
                         "nextcloud.folder.create",
                         "nextcloud.file.upload",
                         "nextcloud.node.move",
                         "nextcloud.node.copy"
                       ]

  @files_destructive_tools @files_write_tools ++
                             [
                               "nextcloud.node.delete"
                             ]

  @sharing_tools @files_readonly_tools ++
                   [
                     "nextcloud.shares.list",
                     "nextcloud.share.get",
                     "nextcloud.share.create",
                     "nextcloud.share.update",
                     "nextcloud.share.delete",
                     "nextcloud.sharees.search"
                   ]

  @office_tools @files_readonly_tools ++
                  [
                    "nextcloud.office.launch_token.get"
                  ]

  @full_tools Enum.uniq(@files_destructive_tools ++ @sharing_tools ++ @office_tools)

  @doc "Returns all built-in Nextcloud catalog packs."
  def all do
    [files_readonly(), files_write(), files_destructive(), sharing(), office(), full()]
  end

  @doc "Read-only Nextcloud files and Office capability metadata."
  def files_readonly do
    Pack.new!(%{
      id: :nextcloud_files_readonly,
      label: "Nextcloud files read-only",
      description: "Read Nextcloud file metadata, search files, and download file content.",
      filters: %{provider: :nextcloud},
      allowed_tools: @files_readonly_tools,
      metadata: %{package: :jido_connect_nextcloud, risk: :read}
    })
  end

  @doc "Nextcloud files read/write pack without delete."
  def files_write do
    Pack.new!(%{
      id: :nextcloud_files_write,
      label: "Nextcloud files write",
      description: "Read and write Nextcloud files and folders. Excludes delete and sharing.",
      filters: %{provider: :nextcloud},
      allowed_tools: @files_write_tools,
      metadata: %{
        package: :jido_connect_nextcloud,
        excludes: ["nextcloud.node.delete", "nextcloud.share.delete"]
      }
    })
  end

  @doc "Nextcloud files pack including delete."
  def files_destructive do
    Pack.new!(%{
      id: :nextcloud_files_destructive,
      label: "Nextcloud files destructive",
      description: "Full Nextcloud file operations including delete.",
      filters: %{provider: :nextcloud},
      allowed_tools: @files_destructive_tools,
      metadata: %{package: :jido_connect_nextcloud, risk: :destructive}
    })
  end

  @doc "Nextcloud OCS sharing pack."
  def sharing do
    Pack.new!(%{
      id: :nextcloud_sharing,
      label: "Nextcloud sharing",
      description: "Nextcloud file sharing, share lookup, and sharee search tools.",
      filters: %{provider: :nextcloud},
      allowed_tools: @sharing_tools,
      metadata: %{package: :jido_connect_nextcloud, risk: :external_write}
    })
  end

  @doc "Nextcloud Office pack."
  def office do
    Pack.new!(%{
      id: :nextcloud_office,
      label: "Nextcloud Office",
      description: "Nextcloud Office capability and richdocuments external-app launch tools.",
      filters: %{provider: :nextcloud},
      allowed_tools: @office_tools,
      metadata: %{package: :jido_connect_nextcloud, risk: :external_write}
    })
  end

  @doc "Full Nextcloud pack."
  def full do
    Pack.new!(%{
      id: :nextcloud_full,
      label: "Nextcloud full",
      description: "Full Nextcloud Files, sharing, and Office external-app access.",
      filters: %{provider: :nextcloud},
      allowed_tools: @full_tools,
      metadata: %{package: :jido_connect_nextcloud, risk: :destructive}
    })
  end
end
