defmodule Jido.Connect.Google.Drive.CatalogPacksTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Catalog
  alias Jido.Connect.Google.Drive

  defmodule FakeDriveClient do
    def create_file(
          %{
            name: "Notes",
            mime_type: "text/plain",
            supports_all_drives: false
          },
          "token"
        ) do
      {:ok,
       Drive.File.new!(%{
         file_id: "created123",
         name: "Notes",
         mime_type: "text/plain"
       })}
    end

    def upload_file(
          %{
            name: "Notes",
            content: "hello",
            mime_type: "text/plain",
            supports_all_drives: false
          },
          "token"
        ) do
      {:ok,
       Drive.File.new!(%{
         file_id: "uploaded123",
         name: "Notes",
         mime_type: "text/plain"
       })}
    end
  end

  test "readonly pack restricts search and describe to read tools" do
    results =
      Catalog.search_tools("drive",
        modules: [Drive],
        packs: Drive.catalog_packs(),
        pack: :google_drive_readonly
      )

    ids = Enum.map(results, & &1.tool.id)

    assert "google.drive.file.get" in ids
    assert "google.drive.file.export" in ids
    assert "google.drive.file.changed" in ids
    assert "google.drive.file.changed.push" in ids
    assert "google.drive.permission.get" in ids
    assert "google.drive.revisions.list" in ids
    assert "google.drive.revision.get" in ids
    assert "google.drive.comments.list" in ids
    assert "google.drive.comment.get" in ids
    assert "google.drive.replies.list" in ids
    assert "google.drive.reply.get" in ids
    assert "google.drive.shared_drives.list" in ids
    assert "google.drive.shared_drive.get" in ids
    assert "google.drive.changes.get_start_page_token" in ids
    assert "google.drive.changes.list" in ids
    assert "google.drive.collection.changes.list" in ids
    assert "google.drive.collection.changes" in ids
    assert "google.drive.collection.changes.push" in ids
    refute "google.drive.changes.watch" in ids
    refute "google.drive.collection.watch" in ids
    refute "google.drive.file.create" in ids
    refute "google.drive.file.upload" in ids
    refute "google.drive.permission.update" in ids
    refute "google.drive.revision.delete" in ids
    refute "google.drive.comment.create" in ids
    refute "google.drive.reply.create" in ids
    refute "google.drive.shared_drive.create" in ids

    assert {:ok, descriptor} =
             Catalog.describe_tool("google.drive.file.get",
               modules: [Drive],
               packs: Drive.catalog_packs(),
               pack: :google_drive_readonly
             )

    assert descriptor.tool.id == "google.drive.file.get"

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.describe_tool("google.drive.file.create",
               modules: [Drive],
               packs: Drive.catalog_packs(),
               pack: :google_drive_readonly
             )
  end

  test "file writer pack allows common writes but rejects broad actions" do
    assert {:ok, descriptor} =
             Catalog.describe_tool("google.drive.file.create",
               modules: [Drive],
               packs: Drive.catalog_packs(),
               pack: :google_drive_file_writer
             )

    assert descriptor.tool.id == "google.drive.file.create"

    assert {:ok, upload_descriptor} =
             Catalog.describe_tool("google.drive.file.upload",
               modules: [Drive],
               packs: Drive.catalog_packs(),
               pack: :google_drive_file_writer
             )

    assert upload_descriptor.tool.id == "google.drive.file.upload"
    assert upload_descriptor.tool.verb == :upload

    input = Map.new(upload_descriptor.input, &{&1.name, &1})
    assert input.name.required?
    refute input.content.required?
    refute input.content_base64.required?
    assert input.mime_type.default == "application/octet-stream"
    assert Map.has_key?(input, :parents)
    assert Map.has_key?(input, :description)
    assert Map.has_key?(input, :fields)
    assert input.supports_all_drives.default == false

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.describe_tool("google.drive.file.delete",
               modules: [Drive],
               packs: Drive.catalog_packs(),
               pack: :google_drive_file_writer
             )

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.describe_tool("google.drive.permission.create",
               modules: [Drive],
               packs: Drive.catalog_packs(),
               pack: :google_drive_file_writer
             )

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.describe_tool("google.drive.permission.update",
               modules: [Drive],
               packs: Drive.catalog_packs(),
               pack: :google_drive_file_writer
             )

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.describe_tool("google.drive.revision.delete",
               modules: [Drive],
               packs: Drive.catalog_packs(),
               pack: :google_drive_file_writer
             )

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.describe_tool("google.drive.comment.create",
               modules: [Drive],
               packs: Drive.catalog_packs(),
               pack: :google_drive_file_writer
             )

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.describe_tool("google.drive.reply.create",
               modules: [Drive],
               packs: Drive.catalog_packs(),
               pack: :google_drive_file_writer
             )

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.describe_tool("google.drive.shared_drive.delete",
               modules: [Drive],
               packs: Drive.catalog_packs(),
               pack: :google_drive_file_writer
             )

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.describe_tool("google.drive.changes.watch",
               modules: [Drive],
               packs: Drive.catalog_packs(),
               pack: :google_drive_file_writer
             )

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.describe_tool("google.drive.collection.watch",
               modules: [Drive],
               packs: Drive.catalog_packs(),
               pack: :google_drive_file_writer
             )
  end

  test "watch pack exposes Drive channel lifecycle and webhook metadata" do
    assert {:ok, descriptor} =
             Catalog.describe_tool("google.drive.changes.watch",
               modules: [Drive],
               packs: Drive.catalog_packs(),
               pack: :google_drive_watch
             )

    assert descriptor.tool.id == "google.drive.changes.watch"

    assert {:ok, token_descriptor} =
             Catalog.describe_tool("google.drive.changes.get_start_page_token",
               modules: [Drive],
               packs: Drive.catalog_packs(),
               pack: :google_drive_watch
             )

    assert token_descriptor.tool.id == "google.drive.changes.get_start_page_token"

    assert {:ok, list_descriptor} =
             Catalog.describe_tool("google.drive.changes.list",
               modules: [Drive],
               packs: Drive.catalog_packs(),
               pack: :google_drive_watch
             )

    assert list_descriptor.tool.id == "google.drive.changes.list"

    assert {:ok, collection_watch_descriptor} =
             Catalog.describe_tool("google.drive.collection.watch",
               modules: [Drive],
               packs: Drive.catalog_packs(),
               pack: :google_drive_watch
             )

    assert collection_watch_descriptor.tool.id == "google.drive.collection.watch"

    assert {:ok, collection_changes_descriptor} =
             Catalog.describe_tool("google.drive.collection.changes.list",
               modules: [Drive],
               packs: Drive.catalog_packs(),
               pack: :google_drive_watch
             )

    assert collection_changes_descriptor.tool.id == "google.drive.collection.changes.list"

    assert {:ok, collection_poll_descriptor} =
             Catalog.describe_tool("google.drive.collection.changes",
               modules: [Drive],
               packs: Drive.catalog_packs(),
               pack: :google_drive_watch
             )

    assert collection_poll_descriptor.tool.id == "google.drive.collection.changes"

    assert {:ok, collection_push_descriptor} =
             Catalog.describe_tool("google.drive.collection.changes.push",
               modules: [Drive],
               packs: Drive.catalog_packs(),
               pack: :google_drive_watch
             )

    assert collection_push_descriptor.tool.id == "google.drive.collection.changes.push"

    assert {:ok, file_descriptor} =
             Catalog.describe_tool("google.drive.file.watch",
               modules: [Drive],
               packs: Drive.catalog_packs(),
               pack: :google_drive_watch
             )

    assert file_descriptor.tool.id == "google.drive.file.watch"

    assert {:ok, webhook_descriptor} =
             Catalog.describe_tool("google.drive.file.changed.push",
               modules: [Drive],
               packs: Drive.catalog_packs(),
               pack: :google_drive_watch
             )

    assert webhook_descriptor.tool.id == "google.drive.file.changed.push"

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.describe_tool("google.drive.file.delete",
               modules: [Drive],
               packs: Drive.catalog_packs(),
               pack: :google_drive_watch
             )
  end

  test "pack restrictions apply to call_tool" do
    {context, lease} = context_and_lease()

    assert {:ok, %{file: %{file_id: "created123"}}} =
             Catalog.call_tool(
               "google.drive.file.create",
               %{name: "Notes", mime_type: "text/plain"},
               modules: [Drive],
               packs: Drive.catalog_packs(),
               pack: :google_drive_file_writer,
               context: context,
               credential_lease: lease
             )

    assert {:ok, %{file: %{file_id: "uploaded123"}}} =
             Catalog.call_tool(
               "google.drive.file.upload",
               %{name: "Notes", content: "hello", mime_type: "text/plain"},
               modules: [Drive],
               packs: Drive.catalog_packs(),
               pack: :google_drive_file_writer,
               context: context,
               credential_lease: lease
             )

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.call_tool(
               "google.drive.file.upload",
               %{name: "Notes", content: "hello", mime_type: "text/plain"},
               modules: [Drive],
               packs: Drive.catalog_packs(),
               pack: :google_drive_readonly,
               context: context,
               credential_lease: lease
             )
  end

  defp context_and_lease do
    scopes = [
      "openid",
      "email",
      "profile",
      "https://www.googleapis.com/auth/drive.file"
    ]

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
        fields: %{access_token: "token", google_drive_client: FakeDriveClient},
        scopes: scopes
      })

    {context, lease}
  end
end
