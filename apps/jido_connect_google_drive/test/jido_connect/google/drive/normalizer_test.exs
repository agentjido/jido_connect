defmodule Jido.Connect.Google.Drive.NormalizerTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Drive.{
    Change,
    Channel,
    File,
    Folder,
    Normalizer,
    Permission,
    Revision
  }

  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  test "normalizes file payloads" do
    assert {:ok, %File{} = file} =
             Normalizer.file(%{
               "id" => "file123",
               "name" => "Budget.pdf",
               "mimeType" => "application/pdf",
               "description" => "Quarterly budget",
               "webViewLink" => "https://drive.google.com/file/d/file123/view",
               "size" => "1024",
               "createdTime" => "2026-05-01T10:00:00Z",
               "modifiedTime" => "2026-05-02T10:00:00Z",
               "parents" => ["folder123"],
               "owners" => [%{"emailAddress" => "owner@example.com"}],
               "shared" => true
             })

    assert file.file_id == "file123"
    assert file.name == "Budget.pdf"
    assert file.size == 1024
    assert file.parents == ["folder123"]
    assert file.shared?
  end

  test "normalizes folder payloads" do
    assert {:ok, %Folder{} = folder} =
             Normalizer.folder(%{
               "id" => "folder123",
               "name" => "Reports",
               "mimeType" => "application/vnd.google-apps.folder",
               "webViewLink" => "https://drive.google.com/drive/folders/folder123",
               "parents" => ["root"],
               "shared" => false
             })

    assert folder.folder_id == "folder123"
    assert folder.name == "Reports"
    assert folder.parents == ["root"]
    refute folder.shared?
  end

  test "normalizes permission payloads" do
    assert {:ok, %Permission{} = permission} =
             Normalizer.permission(%{
               "id" => "perm123",
               "type" => "user",
               "role" => "reader",
               "emailAddress" => "reader@example.com",
               "displayName" => "Reader",
               "allowFileDiscovery" => false
             })

    assert permission.permission_id == "perm123"
    assert permission.type == "user"
    assert permission.role == "reader"
    assert permission.email_address == "reader@example.com"
    refute permission.allow_file_discovery?
  end

  test "normalizes revision payloads" do
    assert {:ok, %Revision{} = revision} =
             Normalizer.revision(%{
               "id" => "rev1",
               "mimeType" => "application/pdf",
               "kind" => "drive#revision",
               "published" => false,
               "keepForever" => true,
               "md5Checksum" => "abc123",
               "modifiedTime" => "2026-05-05T12:00:00Z",
               "publishAuto" => false,
               "publishedOutsideDomain" => false,
               "publishedLink" => "https://docs.google.com/document/d/file123/pub",
               "size" => "4096",
               "originalFilename" => "Budget.pdf",
               "lastModifyingUser" => %{"emailAddress" => "owner@example.com"},
               "exportLinks" => %{"application/pdf" => "https://example.com/export"}
             })

    assert revision.revision_id == "rev1"
    assert revision.mime_type == "application/pdf"
    assert revision.keep_forever?
    refute revision.published?
    assert revision.size == 4096
    assert revision.export_links == %{"application/pdf" => "https://example.com/export"}
  end

  test "normalizes change payloads with embedded files" do
    assert {:ok, %Change{} = change} =
             Normalizer.change(%{
               "changeId" => 42,
               "fileId" => "file123",
               "removed" => false,
               "time" => "2026-05-02T10:00:00Z",
               "file" => %{
                 "id" => "file123",
                 "name" => "Budget.pdf",
                 "mimeType" => "application/pdf"
               }
             })

    assert change.change_id == "42"
    assert change.file_id == "file123"
    assert change.file.name == "Budget.pdf"
    refute change.removed?
  end

  test "normalizes channel payloads" do
    assert {:ok, %Channel{} = channel} =
             Normalizer.channel(%{
               "kind" => "api#channel",
               "id" => "channel-123",
               "resourceId" => "resource-123",
               "resourceUri" => "https://www.googleapis.com/drive/v3/changes",
               "token" => "route=drive",
               "expiration" => 1_770_000_000_000
             })

    assert channel.channel_id == "channel-123"
    assert channel.resource_id == "resource-123"
    assert channel.resource_uri == "https://www.googleapis.com/drive/v3/changes"
    assert channel.token == "route=drive"
    assert channel.expiration == "1770000000000"
  end

  test "returns errors instead of raising for malformed embedded change files" do
    assert {:error, _error} =
             Normalizer.change(%{
               "changeId" => 42,
               "fileId" => "file123",
               "file" => %{"id" => "file123"}
             })
  end

  test "detects folder payloads" do
    assert Normalizer.folder?(%{"mimeType" => "application/vnd.google-apps.folder"})
    refute Normalizer.folder?(%{"mimeType" => "application/pdf"})
  end

  test "struct constructors expose schema defaults" do
    ConnectorContracts.assert_struct_defaults(File, %{file_id: "file123", name: "Budget.pdf"},
      parents: [],
      owners: [],
      shared?: false,
      trashed?: false,
      starred?: false,
      metadata: %{}
    )

    assert {:error, _error} = File.new(%{name: "Missing id"})

    ConnectorContracts.assert_struct_defaults(Folder, %{folder_id: "folder123", name: "Reports"},
      parents: [],
      shared?: false,
      trashed?: false,
      metadata: %{}
    )

    assert {:error, _error} = Folder.new(%{name: "Missing id"})

    ConnectorContracts.assert_struct_defaults(
      Permission,
      %{permission_id: "perm123", type: "user", role: "reader"},
      deleted?: false,
      metadata: %{}
    )

    assert {:error, _error} = Permission.new(%{permission_id: "perm123"})

    ConnectorContracts.assert_struct_defaults(Change, %{}, removed?: false, metadata: %{})

    ConnectorContracts.assert_struct_defaults(Channel, %{channel_id: "channel-123"},
      params: %{},
      metadata: %{}
    )

    ConnectorContracts.assert_struct_defaults(Revision, %{revision_id: "rev1"},
      published?: false,
      keep_forever?: false,
      publish_auto?: false,
      published_outside_domain?: false,
      export_links: %{},
      metadata: %{}
    )

    assert {:error, _error} = Revision.new(%{})
  end
end
