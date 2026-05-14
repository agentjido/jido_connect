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

  test "metadata pack exposes only read and poll tools" do
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
    assert "google.gmail.message.received" in ids
    assert "google.gmail.mailbox.changed" in ids
    refute "google.gmail.label.get" in ids
    refute "google.gmail.message.attachment.get" in ids
    refute "google.gmail.watch.start" in ids
    refute "google.gmail.message.send" in ids
    refute "google.gmail.label.create" in ids
    refute "google.gmail.message.delete" in ids

    assert {:ok, descriptor} =
             Catalog.describe_tool("google.gmail.message.received",
               modules: [Gmail],
               packs: Gmail.catalog_packs(),
               pack: :google_gmail_metadata
             )

    assert descriptor.tool.id == "google.gmail.message.received"

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

    assert {:ok, thread_descriptor} =
             Catalog.describe_tool("google.gmail.thread.trash",
               modules: [Gmail],
               packs: Gmail.catalog_packs(),
               pack: :google_gmail_triage
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
