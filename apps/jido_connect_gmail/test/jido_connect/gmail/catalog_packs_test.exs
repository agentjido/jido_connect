defmodule Jido.Connect.Gmail.CatalogPacksTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Catalog
  alias Jido.Connect.Gmail

  defmodule FakeGmailClient do
    def create_label(%{name: "Customers"}, "token") do
      {:ok,
       Gmail.Label.new!(%{
         label_id: "Label_123",
         name: "Customers",
         type: "user"
       })}
    end

    def send_message(%{raw: raw, to: ["to@example.com"], subject: "Hello"}, "token")
        when is_binary(raw) do
      {:ok,
       Gmail.Message.new!(%{
         message_id: "sent123",
         thread_id: "thread123",
         label_ids: ["SENT"]
       })}
    end
  end

  test "metadata pack exposes only read Actions" do
    results =
      Catalog.search_tools("gmail",
        modules: [Gmail],
        packs: Gmail.catalog_packs(),
        pack: :google_gmail_metadata
      )

    ids = Enum.map(results, & &1.tool.id)

    assert "google.gmail.profile.get" in ids
    assert "google.gmail.message.get" in ids
    assert "google.gmail.history.list" in ids
    refute "google.gmail.message.received" in ids
    refute "google.gmail.mailbox.changed" in ids
    refute "google.gmail.label.get" in ids
    refute "google.gmail.message.attachment.get" in ids
    refute "google.gmail.watch.start" in ids
    refute "google.gmail.message.send" in ids
    refute "google.gmail.label.create" in ids
    refute "google.gmail.message.delete" in ids

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.describe_tool("google.gmail.message.received",
               modules: [Gmail],
               packs: Gmail.catalog_packs(),
               pack: :google_gmail_metadata
             )

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.describe_tool("google.gmail.message.send",
               modules: [Gmail],
               packs: Gmail.catalog_packs(),
               pack: :google_gmail_metadata
             )
  end

  test "triage pack allows mailbox organization, watch, and attachments and rejects send and permanent delete tools" do
    assert {:ok, descriptor} =
             Catalog.describe_tool("google.gmail.message.labels.apply",
               modules: [Gmail],
               packs: Gmail.catalog_packs(),
               pack: :google_gmail_triage
             )

    assert descriptor.tool.id == "google.gmail.message.labels.apply"

    assert {:ok, label_descriptor} =
             Catalog.describe_tool("google.gmail.label.get",
               modules: [Gmail],
               packs: Gmail.catalog_packs(),
               pack: :google_gmail_triage
             )

    assert label_descriptor.tool.id == "google.gmail.label.get"

    assert {:ok, batch_descriptor} =
             Catalog.describe_tool("google.gmail.messages.batch_modify",
               modules: [Gmail],
               packs: Gmail.catalog_packs(),
               pack: :google_gmail_triage
             )

    assert batch_descriptor.tool.id == "google.gmail.messages.batch_modify"

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.describe_tool("google.gmail.thread.trash",
               modules: [Gmail],
               packs: Gmail.catalog_packs(),
               pack: :google_gmail_triage
             )

    assert {:ok, thread_descriptor} =
             Catalog.describe_tool("google.gmail.thread.trash",
               modules: [Gmail],
               packs: Gmail.catalog_packs(),
               pack: :google_gmail_destructive
             )

    assert thread_descriptor.tool.id == "google.gmail.thread.trash"

    assert {:ok, watch_descriptor} =
             Catalog.describe_tool("google.gmail.watch.start",
               modules: [Gmail],
               packs: Gmail.catalog_packs(),
               pack: :google_gmail_triage
             )

    assert watch_descriptor.tool.id == "google.gmail.watch.start"

    assert {:ok, attachment_descriptor} =
             Catalog.describe_tool("google.gmail.message.attachment.get",
               modules: [Gmail],
               packs: Gmail.catalog_packs(),
               pack: :google_gmail_triage
             )

    assert attachment_descriptor.tool.id == "google.gmail.message.attachment.get"

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.describe_tool("google.gmail.message.send",
               modules: [Gmail],
               packs: Gmail.catalog_packs(),
               pack: :google_gmail_triage
             )

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.describe_tool("google.gmail.message.delete",
               modules: [Gmail],
               packs: Gmail.catalog_packs(),
               pack: :google_gmail_triage
             )
  end

  test "send pack allows send and non-destructive draft tools and rejects triage mutations" do
    assert {:ok, descriptor} =
             Catalog.describe_tool("google.gmail.message.send",
               modules: [Gmail],
               packs: Gmail.catalog_packs(),
               pack: :google_gmail_send
             )

    assert descriptor.tool.id == "google.gmail.message.send"

    assert {:ok, draft_descriptor} =
             Catalog.describe_tool("google.gmail.draft.create",
               modules: [Gmail],
               packs: Gmail.catalog_packs(),
               pack: :google_gmail_send
             )

    assert draft_descriptor.tool.id == "google.gmail.draft.create"

    assert {:ok, update_draft_descriptor} =
             Catalog.describe_tool("google.gmail.draft.update",
               modules: [Gmail],
               packs: Gmail.catalog_packs(),
               pack: :google_gmail_send
             )

    assert update_draft_descriptor.tool.id == "google.gmail.draft.update"

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.describe_tool("google.gmail.label.create",
               modules: [Gmail],
               packs: Gmail.catalog_packs(),
               pack: :google_gmail_send
             )

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.describe_tool("google.gmail.watch.start",
               modules: [Gmail],
               packs: Gmail.catalog_packs(),
               pack: :google_gmail_send
             )

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.describe_tool("google.gmail.message.attachment.get",
               modules: [Gmail],
               packs: Gmail.catalog_packs(),
               pack: :google_gmail_send
             )

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.describe_tool("google.gmail.draft.delete",
               modules: [Gmail],
               packs: Gmail.catalog_packs(),
               pack: :google_gmail_send
             )
  end

  test "destructive pack exposes explicit delete and trash tools" do
    assert {:ok, descriptor} =
             Catalog.describe_tool("google.gmail.message.delete",
               modules: [Gmail],
               packs: Gmail.catalog_packs(),
               pack: :google_gmail_destructive
             )

    assert descriptor.tool.id == "google.gmail.message.delete"

    assert {:ok, batch_descriptor} =
             Catalog.describe_tool("google.gmail.messages.batch_delete",
               modules: [Gmail],
               packs: Gmail.catalog_packs(),
               pack: :google_gmail_destructive
             )

    assert batch_descriptor.tool.id == "google.gmail.messages.batch_delete"

    assert {:ok, draft_descriptor} =
             Catalog.describe_tool("google.gmail.draft.delete",
               modules: [Gmail],
               packs: Gmail.catalog_packs(),
               pack: :google_gmail_destructive
             )

    assert draft_descriptor.tool.id == "google.gmail.draft.delete"

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.describe_tool("google.gmail.message.send",
               modules: [Gmail],
               packs: Gmail.catalog_packs(),
               pack: :google_gmail_destructive
             )
  end

  test "content pack is an opt-in read pack with metadata reads and attachment content" do
    pack = Gmail.content_pack()

    assert pack.id == :google_gmail_content
    assert pack.metadata.risk == :read
    assert pack in Gmail.catalog_packs()

    ids =
      "gmail"
      |> Catalog.search_tools(
        modules: [Gmail],
        packs: Gmail.catalog_packs(),
        pack: :google_gmail_content
      )
      |> MapSet.new(& &1.tool.id)

    assert ids ==
             MapSet.new([
               "google.gmail.profile.get",
               "google.gmail.labels.list",
               "google.gmail.messages.list",
               "google.gmail.message.get",
               "google.gmail.threads.list",
               "google.gmail.thread.get",
               "google.gmail.history.list",
               "google.gmail.message.attachment.get"
             ])

    assert {:ok, descriptor} =
             Catalog.describe_tool("google.gmail.message.attachment.get",
               modules: [Gmail],
               packs: Gmail.catalog_packs(),
               pack: :google_gmail_content
             )

    assert descriptor.tool.id == "google.gmail.message.attachment.get"
  end

  test "content pack rejects send, mutation, and delete tools" do
    for tool_id <- [
          "google.gmail.message.send",
          "google.gmail.draft.create",
          "google.gmail.draft.update",
          "google.gmail.draft.send",
          "google.gmail.draft.delete",
          "google.gmail.label.create",
          "google.gmail.label.update",
          "google.gmail.label.delete",
          "google.gmail.message.labels.apply",
          "google.gmail.messages.batch_modify",
          "google.gmail.thread.modify",
          "google.gmail.message.trash",
          "google.gmail.message.untrash",
          "google.gmail.thread.trash",
          "google.gmail.thread.untrash",
          "google.gmail.message.delete",
          "google.gmail.messages.batch_delete",
          "google.gmail.thread.delete",
          "google.gmail.watch.start",
          "google.gmail.watch.stop"
        ] do
      assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
               Catalog.describe_tool(tool_id,
                 modules: [Gmail],
                 packs: Gmail.catalog_packs(),
                 pack: :google_gmail_content
               ),
             "#{tool_id} must not be in the content pack"
    end
  end

  test "existing packs keep their tools and risk" do
    metadata_tools = [
      "google.gmail.profile.get",
      "google.gmail.labels.list",
      "google.gmail.messages.list",
      "google.gmail.message.get",
      "google.gmail.threads.list",
      "google.gmail.thread.get",
      "google.gmail.history.list"
    ]

    assert Gmail.metadata_pack().allowed_tools == metadata_tools
    assert Gmail.metadata_pack().metadata.risk == :read

    assert Gmail.triage_pack().allowed_tools ==
             metadata_tools ++
               [
                 "google.gmail.watch.start",
                 "google.gmail.watch.stop",
                 "google.gmail.label.get",
                 "google.gmail.message.attachment.get",
                 "google.gmail.label.create",
                 "google.gmail.label.update",
                 "google.gmail.message.labels.apply",
                 "google.gmail.messages.batch_modify",
                 "google.gmail.message.untrash",
                 "google.gmail.thread.modify",
                 "google.gmail.thread.untrash"
               ]

    assert Gmail.triage_pack().metadata.risk == :write

    assert Gmail.send_pack().allowed_tools ==
             metadata_tools ++
               [
                 "google.gmail.message.send",
                 "google.gmail.drafts.list",
                 "google.gmail.draft.get",
                 "google.gmail.draft.create",
                 "google.gmail.draft.update",
                 "google.gmail.draft.send"
               ]

    assert Gmail.send_pack().metadata.risk == :write

    assert Gmail.destructive_pack().allowed_tools ==
             metadata_tools ++
               [
                 "google.gmail.draft.delete",
                 "google.gmail.label.delete",
                 "google.gmail.message.trash",
                 "google.gmail.message.delete",
                 "google.gmail.messages.batch_delete",
                 "google.gmail.thread.trash",
                 "google.gmail.thread.delete"
               ]

    assert Gmail.destructive_pack().metadata.risk == :destructive

    assert Enum.map(Gmail.catalog_packs(), & &1.id) == [
             :google_gmail_metadata,
             :google_gmail_triage,
             :google_gmail_send,
             :google_gmail_destructive,
             :google_gmail_content
           ]
  end

  test "pack restrictions apply to call_tool" do
    {context, lease} = context_and_lease(scopes: modify_scopes())

    assert {:ok, %{label: %{label_id: "Label_123"}}} =
             Catalog.call_tool(
               "google.gmail.label.create",
               %{name: "Customers"},
               modules: [Gmail],
               packs: Gmail.catalog_packs(),
               pack: :google_gmail_triage,
               context: context,
               credential_lease: lease
             )

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.call_tool(
               "google.gmail.label.create",
               %{name: "Customers"},
               modules: [Gmail],
               packs: Gmail.catalog_packs(),
               pack: :google_gmail_send,
               context: context,
               credential_lease: lease
             )

    {context, lease} = context_and_lease(scopes: send_scopes())

    assert {:ok, %{message: %{message_id: "sent123"}}} =
             Catalog.call_tool(
               "google.gmail.message.send",
               %{to: ["to@example.com"], subject: "Hello", body_text: "Body"},
               modules: [Gmail],
               packs: Gmail.catalog_packs(),
               pack: :google_gmail_send,
               context: context,
               credential_lease: lease
             )

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.call_tool(
               "google.gmail.message.send",
               %{to: ["to@example.com"], subject: "Hello", body_text: "Body"},
               modules: [Gmail],
               packs: Gmail.catalog_packs(),
               pack: :google_gmail_triage,
               context: context,
               credential_lease: lease
             )
  end

  defp context_and_lease(opts) do
    scopes = Keyword.fetch!(opts, :scopes)

    connection =
      Connect.Connection.new!(%{
        id: "conn_1",
        provider: :google,
        profile: :user,
        tenant_id: "tenant_1",
        owner_type: :app_user,
        owner_id: "user_1",
        status: :connected,
        scopes: scopes
      })

    context =
      Connect.Context.new!(%{
        tenant_id: "tenant_1",
        actor: %{id: "user_1", type: :user},
        connection: connection
      })

    lease =
      Connect.CredentialLease.new!(%{
        connection_id: "conn_1",
        provider: :google,
        profile: :user,
        expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
        fields: %{access_token: "token", gmail_client: FakeGmailClient},
        scopes: scopes
      })

    {context, lease}
  end

  defp modify_scopes do
    ["openid", "email", "profile", "https://www.googleapis.com/auth/gmail.modify"]
  end

  defp send_scopes do
    ["openid", "email", "profile", "https://www.googleapis.com/auth/gmail.send"]
  end
end
