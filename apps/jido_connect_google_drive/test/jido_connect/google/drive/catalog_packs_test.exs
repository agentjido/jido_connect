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
    refute "google.drive.changes.watch" in ids
    refute "google.drive.file.create" in ids
    refute "google.drive.permission.update" in ids
    refute "google.drive.revision.delete" in ids

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
             Catalog.describe_tool("google.drive.changes.watch",
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

    assert {:error, %Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.call_tool(
               "google.drive.file.create",
               %{name: "Notes", mime_type: "text/plain"},
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
