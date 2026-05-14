defmodule Jido.Connect.Gmail.CatalogPacks do
  @moduledoc "Curated catalog packs for common Gmail tool surfaces."

  alias Jido.Connect.Catalog.Pack

  @metadata_tools [
    "google.gmail.profile.get",
    "google.gmail.labels.list",
    "google.gmail.messages.list",
    "google.gmail.message.get",
    "google.gmail.threads.list",
    "google.gmail.thread.get",
    "google.gmail.history.list",
    "google.gmail.message.received"
  ]

  @webhook_tools [
    "google.gmail.mailbox.changed"
  ]

  @watch_tools [
    "google.gmail.watch.start",
    "google.gmail.watch.stop"
  ]

  @content_read_tools [
    "google.gmail.label.get",
    "google.gmail.message.attachment.get"
  ]

  @triage_tools @metadata_tools ++
                  @webhook_tools ++
                  @watch_tools ++
                  @content_read_tools ++
                  [
                    "google.gmail.label.create",
                    "google.gmail.label.update",
                    "google.gmail.message.labels.apply",
                    "google.gmail.messages.batch_modify",
                    "google.gmail.message.trash",
                    "google.gmail.message.untrash",
                    "google.gmail.thread.modify",
                    "google.gmail.thread.trash",
                    "google.gmail.thread.untrash"
                  ]

  @send_tools @metadata_tools ++
                @webhook_tools ++
                [
                  "google.gmail.message.send",
                  "google.gmail.drafts.list",
                  "google.gmail.draft.get",
                  "google.gmail.draft.create",
                  "google.gmail.draft.update",
                  "google.gmail.draft.send"
                ]

  @destructive_tools @metadata_tools ++
                       @webhook_tools ++
                       [
                         "google.gmail.draft.delete",
                         "google.gmail.label.delete",
                         "google.gmail.message.trash",
                         "google.gmail.message.delete",
                         "google.gmail.messages.batch_delete",
                         "google.gmail.thread.trash",
                         "google.gmail.thread.delete"
                       ]

  @doc "Returns all built-in Gmail catalog packs."
  def all, do: [metadata(), triage(), send(), destructive()]

  @doc "Read-only Gmail metadata and message-received polling pack."
  def metadata do
    Pack.new!(%{
      id: :google_gmail_metadata,
      label: "Gmail metadata",
      description:
        "Read Gmail metadata, list history, and poll received message metadata without mutation tools.",
      filters: %{provider: :gmail},
      allowed_tools: @metadata_tools ++ @webhook_tools,
      metadata: %{package: :jido_connect_gmail, risk: :read}
    })
  end

  @doc "Gmail triage pack for reading and label management."
  def triage do
    Pack.new!(%{
      id: :google_gmail_triage,
      label: "Gmail triage",
      description:
        "Read Gmail metadata and attachments, manage push watches, poll received messages, and manage labels. Excludes send and draft tools.",
      filters: %{provider: :gmail},
      allowed_tools: @triage_tools,
      metadata: %{
        package: :jido_connect_gmail,
        excludes: [
          "google.gmail.message.send",
          "google.gmail.draft.create",
          "google.gmail.draft.update",
          "google.gmail.draft.send",
          "google.gmail.draft.delete",
          "google.gmail.label.delete",
          "google.gmail.message.delete",
          "google.gmail.messages.batch_delete",
          "google.gmail.thread.delete"
        ]
      }
    })
  end

  @doc "Gmail send pack for compose, draft, and send workflows."
  def send do
    Pack.new!(%{
      id: :google_gmail_send,
      label: "Gmail send",
      description:
        "Read Gmail metadata, receive mailbox-change webhook metadata, and send or draft messages. Excludes label mutations.",
      filters: %{provider: :gmail},
      allowed_tools: @send_tools,
      metadata: %{
        package: :jido_connect_gmail,
        excludes: [
          "google.gmail.label.create",
          "google.gmail.label.update",
          "google.gmail.label.delete",
          "google.gmail.message.labels.apply",
          "google.gmail.messages.batch_modify",
          "google.gmail.message.trash",
          "google.gmail.message.untrash",
          "google.gmail.message.delete",
          "google.gmail.messages.batch_delete",
          "google.gmail.thread.modify",
          "google.gmail.thread.trash",
          "google.gmail.thread.untrash",
          "google.gmail.thread.delete"
        ]
      }
    })
  end

  @doc "Gmail destructive pack for explicit delete and trash workflows."
  def destructive do
    Pack.new!(%{
      id: :google_gmail_destructive,
      label: "Gmail destructive",
      description:
        "Read Gmail metadata and expose explicit draft, label, message, and thread delete or trash operations.",
      filters: %{provider: :gmail},
      allowed_tools: @destructive_tools,
      metadata: %{package: :jido_connect_gmail, risk: :destructive}
    })
  end
end
