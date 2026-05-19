defmodule Jido.Connect.MicrosoftOutlook.CatalogPacks do
  @moduledoc "Curated catalog packs for common Outlook Mail tool surfaces."

  alias Jido.Connect.Catalog.Pack

  @metadata_tools [
    "microsoft.outlook.profile.get",
    "microsoft.outlook.messages.list",
    "microsoft.outlook.folders.list"
  ]

  @triage_tools @metadata_tools ++
                  [
                    "microsoft.outlook.message.get",
                    "microsoft.outlook.folder.get",
                    "microsoft.outlook.message.move"
                  ]

  @send_tools @metadata_tools ++
                [
                  "microsoft.outlook.draft.create",
                  "microsoft.outlook.draft.update",
                  "microsoft.outlook.draft.send",
                  "microsoft.outlook.message.send",
                  "microsoft.outlook.message.reply",
                  "microsoft.outlook.message.reply_all"
                ]

  @destructive_tools @metadata_tools ++
                       [
                         "microsoft.outlook.message.delete",
                         "microsoft.outlook.draft.delete"
                       ]

  @doc "Returns all built-in Outlook Mail catalog packs."
  def all, do: [metadata(), triage(), send(), destructive()]

  @doc "Read-only Outlook Mail metadata pack."
  def metadata do
    Pack.new!(%{
      id: :microsoft_outlook_metadata,
      label: "Outlook Mail metadata",
      description:
        "Read Outlook Mail profile, message list, and folder metadata without mutation tools.",
      filters: %{provider: :microsoft_outlook},
      allowed_tools: @metadata_tools,
      metadata: %{package: :jido_connect_microsoft_outlook, risk: :read}
    })
  end

  @doc "Outlook Mail triage pack for reading and organizing messages."
  def triage do
    Pack.new!(%{
      id: :microsoft_outlook_triage,
      label: "Outlook Mail triage",
      description:
        "Read Outlook Mail messages and folders, and move messages between folders. Excludes send, draft, and permanent delete tools.",
      filters: %{provider: :microsoft_outlook},
      allowed_tools: @triage_tools,
      metadata: %{
        package: :jido_connect_microsoft_outlook,
        excludes: [
          "microsoft.outlook.message.send",
          "microsoft.outlook.draft.create",
          "microsoft.outlook.draft.update",
          "microsoft.outlook.draft.send",
          "microsoft.outlook.message.delete",
          "microsoft.outlook.draft.delete"
        ]
      }
    })
  end

  @doc "Outlook Mail send pack for compose and send workflows."
  def send do
    Pack.new!(%{
      id: :microsoft_outlook_send,
      label: "Outlook Mail send",
      description:
        "Read Outlook Mail metadata and send or draft messages. Excludes mutation and delete tools.",
      filters: %{provider: :microsoft_outlook},
      allowed_tools: @send_tools,
      metadata: %{
        package: :jido_connect_microsoft_outlook,
        excludes: [
          "microsoft.outlook.message.get",
          "microsoft.outlook.folder.get",
          "microsoft.outlook.message.move",
          "microsoft.outlook.message.delete",
          "microsoft.outlook.draft.delete"
        ]
      }
    })
  end

  @doc "Outlook Mail destructive pack for explicit delete workflows."
  def destructive do
    Pack.new!(%{
      id: :microsoft_outlook_destructive,
      label: "Outlook Mail destructive",
      description:
        "Read Outlook Mail metadata and expose explicit message and draft delete operations.",
      filters: %{provider: :microsoft_outlook},
      allowed_tools: @destructive_tools,
      metadata: %{package: :jido_connect_microsoft_outlook, risk: :destructive}
    })
  end
end
