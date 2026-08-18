defmodule Jido.Connect.Slack.CatalogPacks do
  @moduledoc "Curated Slack catalog packs for the reviewed message and presence surface."

  alias Jido.Connect.Catalog.Pack

  @reader_tools [
    "slack.message.unread.list",
    "slack.thread.replies",
    "slack.presence.get",
    "slack.emoji.list"
  ]

  @editor_tools @reader_tools ++
                  [
                    "slack.message.post",
                    "slack.conversation.mark_read",
                    "slack.presence.set",
                    "slack.profile.status.set",
                    "slack.profile.status.clear"
                  ]

  def all, do: [reader(), editor()]

  def reader do
    Pack.new!(%{
      id: :slack_messages_reader,
      label: "Slack messages and presence reader",
      description: "Read the reviewed Slack thread, unread-message, presence, and emoji surface.",
      filters: %{provider: :slack},
      allowed_tools: @reader_tools,
      metadata: %{package: :jido_connect_slack, risk: :read}
    })
  end

  def editor do
    Pack.new!(%{
      id: :slack_messages_editor,
      label: "Slack messages and presence editor",
      description:
        "Read Slack messages and presence, post messages, move a read cursor, and update the calling user's presence and status.",
      filters: %{provider: :slack},
      allowed_tools: @editor_tools,
      metadata: %{package: :jido_connect_slack, risk: :external_write}
    })
  end
end
