defmodule Jido.Connect.MicrosoftOnedrive.NormalizerTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.MicrosoftOnedrive.Normalizer

  alias Jido.Connect.MicrosoftOnedrive.{
    DeltaToken,
    Download,
    Drive,
    DriveItem,
    FileFacet,
    Folder,
    Permission,
    SharingLink,
    Thumbnail
  }

  # ── Drive ─────────────────────────────────────────────────────────────

  describe "drive/1" do
    test "normalizes a Microsoft Graph drive payload" do
      assert {:ok, %Drive{} = drive} =
               Normalizer.drive(%{
                 "id" => "b!DRIVE1",
                 "driveType" => "personal",
                 "name" => "OneDrive",
                 "webUrl" => "https://contoso-my.sharepoint.com/personal/...",
                 "quota" => %{"total" => 1_099_511_627_776, "used" => 536_870_912}
               })

      assert drive.drive_id == "b!DRIVE1"
      assert drive.drive_type == "personal"
      assert drive.name == "OneDrive"
      assert drive.quota["total"] == 1_099_511_627_776
    end

    test "normalizes a drive with owner and timestamps" do
      assert {:ok, %Drive{} = drive} =
               Normalizer.drive(%{
                 "id" => "b!DRIVE2",
                 "driveType" => "business",
                 "name" => "Team Drive",
                 "owner" => %{
                   "user" => %{
                     "displayName" => "Adele Vance",
                     "email" => "adele@contoso.com",
                     "id" => "USER1"
                   }
                 },
                 "createdDateTime" => "2025-01-15T08:00:00Z",
                 "lastModifiedDateTime" => "2026-05-19T10:00:00Z"
               })

      assert drive.drive_id == "b!DRIVE2"
      assert drive.owner.user.display_name == "Adele Vance"
      assert drive.owner.user.email == "adele@contoso.com"
      assert drive.created_date_time == "2025-01-15T08:00:00Z"
    end

    test "normalizes a drive with minimal fields" do
      assert {:ok, %Drive{} = drive} =
               Normalizer.drive(%{"id" => "b!MIN", "driveType" => "business"})

      assert drive.drive_id == "b!MIN"
      assert drive.drive_type == "business"
      assert is_nil(drive.name)
    end

    test "rejects malformed drive payloads" do
      assert {:error, :invalid_drive_payload} = Normalizer.drive(:bad)
      assert {:error, :invalid_drive_payload} = Normalizer.drive(nil)
    end
  end

  # ── Drive Item ────────────────────────────────────────────────────────

  describe "drive_item/1" do
    test "normalizes a Microsoft Graph driveItem payload" do
      assert {:ok, %DriveItem{} = item} =
               Normalizer.drive_item(%{
                 "id" => "01ABCD1234",
                 "name" => "Quarterly Report.docx",
                 "size" => 1024,
                 "webUrl" => "https://contoso-my.sharepoint.com/personal/...",
                 "createdDateTime" => "2026-05-19T10:00:00Z",
                 "lastModifiedDateTime" => "2026-05-19T12:00:00Z",
                 "folder" => %{"childCount" => 5},
                 "parentReference" => %{"driveId" => "b!DRIVE1"}
               })

      assert item.item_id == "01ABCD1234"
      assert item.name == "Quarterly Report.docx"
      assert item.size == 1024
      assert item.web_url =~ "contoso-my.sharepoint.com"
      assert item.folder.child_count == 5
      assert item.parent_reference["driveId"] == "b!DRIVE1"
    end

    test "normalizes a drive item with minimal fields" do
      assert {:ok, %DriveItem{} = item} =
               Normalizer.drive_item(%{
                 "id" => "01MINIMAL",
                 "name" => "Notes.txt"
               })

      assert item.item_id == "01MINIMAL"
      assert item.name == "Notes.txt"
      assert is_nil(item.size)
      assert is_nil(item.folder)
    end

    test "normalizes a file drive item" do
      assert {:ok, %DriveItem{} = item} =
               Normalizer.drive_item(%{
                 "id" => "01FILE123",
                 "name" => "photo.jpg",
                 "file" => %{"mimeType" => "image/jpeg"}
               })

      assert item.item_id == "01FILE123"
      assert item.file.mime_type == "image/jpeg"
      assert is_nil(item.folder)
    end

    test "normalizes a drive item with embedded permissions and thumbnails" do
      assert {:ok, %DriveItem{} = item} =
               Normalizer.drive_item(%{
                 "id" => "01FULL",
                 "name" => "Full.docx",
                 "permissions" => [
                   %{
                     "id" => "PERM1",
                     "roles" => ["read"],
                     "grantedTo" => %{
                       "user" => %{"displayName" => "Bob", "email" => "bob@contoso.com"}
                     }
                   }
                 ],
                 "thumbnails" => [
                   %{
                     "id" => "0",
                     "width" => 100,
                     "height" => 75,
                     "url" => "https://example.com/thumb"
                   }
                 ]
               })

      assert [%Permission{permission_id: "PERM1", roles: ["read"]}] = item.permissions
      assert [%Thumbnail{id: "0", width: 100}] = item.thumbnails
    end

    test "normalizes a drive item with created_by and last_modified_by" do
      assert {:ok, %DriveItem{} = item} =
               Normalizer.drive_item(%{
                 "id" => "01IDENT",
                 "name" => "Identity.docx",
                 "createdBy" => %{
                   "user" => %{
                     "displayName" => "Adele Vance",
                     "email" => "adele@contoso.com",
                     "id" => "USER1"
                   }
                 },
                 "lastModifiedBy" => %{
                   "user" => %{
                     "displayName" => "Bob Smith",
                     "email" => "bob@contoso.com",
                     "id" => "USER2"
                   }
                 }
               })

      assert item.created_by.user.display_name == "Adele Vance"
      assert item.last_modified_by.user.email == "bob@contoso.com"
    end

    test "rejects malformed drive item payloads" do
      assert {:error, :invalid_drive_item_payload} = Normalizer.drive_item(:bad)
      assert {:error, :invalid_drive_item_payload} = Normalizer.drive_item(nil)
    end
  end

  # ── Folder facet ──────────────────────────────────────────────────────

  describe "folder/1" do
    test "normalizes a folder facet" do
      assert {:ok, %Folder{} = folder} =
               Normalizer.folder(%{
                 "childCount" => 12,
                 "view" => %{"viewType" => "thumbnails", "sortBy" => "name"}
               })

      assert folder.child_count == 12
      assert folder.view["viewType"] == "thumbnails"
    end

    test "normalizes a folder facet with minimal fields" do
      assert {:ok, %Folder{}} = Normalizer.folder(%{})
    end

    test "rejects malformed folder payloads" do
      assert {:error, :invalid_folder_payload} = Normalizer.folder(:bad)
    end
  end

  # ── File facet ────────────────────────────────────────────────────────

  describe "file_facet/1" do
    test "normalizes a file facet" do
      assert {:ok, %FileFacet{} = file} =
               Normalizer.file_facet(%{
                 "mimeType" => "application/pdf",
                 "hashes" => %{"sha1Hash" => "ABC123"}
               })

      assert file.mime_type == "application/pdf"
      assert file.hashes["sha1Hash"] == "ABC123"
    end

    test "normalizes a file facet with minimal fields" do
      assert {:ok, %FileFacet{}} = Normalizer.file_facet(%{})
    end

    test "rejects malformed file facet payloads" do
      assert {:error, :invalid_file_facet_payload} = Normalizer.file_facet(:bad)
    end
  end

  # ── Thumbnail ─────────────────────────────────────────────────────────

  describe "thumbnail/1" do
    test "normalizes a thumbnail payload" do
      assert {:ok, %Thumbnail{} = thumb} =
               Normalizer.thumbnail(%{
                 "id" => "0",
                 "width" => 100,
                 "height" => 75,
                 "url" => "https://example.com/thumb",
                 "sourceItemId" => "01ABCD1234",
                 "contentType" => "image/jpeg"
               })

      assert thumb.id == "0"
      assert thumb.width == 100
      assert thumb.height == 75
      assert thumb.url =~ "example.com"
      assert thumb.source_item_id == "01ABCD1234"
      assert thumb.content_type == "image/jpeg"
    end

    test "normalizes a thumbnail with minimal fields" do
      assert {:ok, %Thumbnail{} = thumb} = Normalizer.thumbnail(%{"width" => 50})

      assert thumb.width == 50
      assert is_nil(thumb.id)
    end

    test "rejects malformed thumbnail payloads" do
      assert {:error, :invalid_thumbnail_payload} = Normalizer.thumbnail(:bad)
    end
  end

  # ── Sharing Link ──────────────────────────────────────────────────────

  describe "sharing_link/1" do
    test "normalizes a sharing link payload" do
      assert {:ok, %SharingLink{} = link} =
               Normalizer.sharing_link(%{
                 "webUrl" => "https://contoso.sharepoint.com/:w:/r/Shared",
                 "type" => "view",
                 "webHtml" => "<a href='...'>View</a>",
                 "preventsDownload" => true,
                 "application" => %{"id" => "APP1", "displayName" => "PowerPoint"}
               })

      assert link.link =~ "contoso.sharepoint.com"
      assert link.type == "view"
      assert link.web_html =~ "View"
      assert link.prevents_download == true
      assert link.application["id"] == "APP1"
    end

    test "normalizes a sharing link with minimal fields" do
      assert {:ok, %SharingLink{} = link} =
               Normalizer.sharing_link(%{"type" => "edit"})

      assert link.type == "edit"
      assert is_nil(link.link)
    end

    test "rejects malformed sharing link payloads" do
      assert {:error, :invalid_sharing_link_payload} = Normalizer.sharing_link(:bad)
    end
  end

  # ── Permission ────────────────────────────────────────────────────────

  describe "permission/1" do
    test "normalizes a permission payload with granted_to" do
      assert {:ok, %Permission{} = perm} =
               Normalizer.permission(%{
                 "id" => "PERM1",
                 "roles" => ["read"],
                 "grantedTo" => %{
                   "user" => %{
                     "displayName" => "Bob Smith",
                     "email" => "bob@contoso.com",
                     "id" => "USER2"
                   }
                 }
               })

      assert perm.permission_id == "PERM1"
      assert perm.roles == ["read"]
      assert perm.granted_to.user.display_name == "Bob Smith"
      assert perm.granted_to.user.email == "bob@contoso.com"
    end

    test "normalizes a permission payload with sharing link" do
      assert {:ok, %Permission{} = perm} =
               Normalizer.permission(%{
                 "id" => "PERM2",
                 "roles" => ["read"],
                 "link" => %{
                   "webUrl" => "https://contoso.sharepoint.com/Shared",
                   "type" => "view",
                   "preventsDownload" => true
                 },
                 "shareId" => "SHARE123",
                 "hasPassword" => false,
                 "grantedToIdentities" => [
                   %{
                     "user" => %{
                       "displayName" => "Carol Davis",
                       "email" => "carol@contoso.com",
                       "id" => "USER3"
                     }
                   }
                 ]
               })

      assert perm.permission_id == "PERM2"
      assert perm.link.type == "view"
      assert perm.link.prevents_download == true
      assert perm.share_id == "SHARE123"
      assert perm.has_password == false
      assert length(perm.granted_to_identities) == 1
    end

    test "normalizes a permission with minimal fields" do
      assert {:ok, %Permission{} = perm} =
               Normalizer.permission(%{"id" => "PERM3"})

      assert perm.permission_id == "PERM3"
      assert perm.roles == []
    end

    test "rejects malformed permission payloads" do
      assert {:error, :invalid_permission_payload} = Normalizer.permission(:bad)
      assert {:error, :invalid_permission_payload} = Normalizer.permission(nil)
    end
  end

  # ── Delta Token ───────────────────────────────────────────────────────

  describe "delta_token/1" do
    test "normalizes a delta token from a delta response envelope" do
      assert {:ok, %DeltaToken{} = dt} =
               Normalizer.delta_token(%{
                 "@odata.deltaToken" => "MzslMjM0OyUyMzE7MjM0NTY3",
                 "value" => []
               })

      assert dt.delta_token == "MzslMjM0OyUyMzE7MjM0NTY3"
      assert is_nil(dt.delta_link)
    end

    test "normalizes a delta link from a delta response envelope" do
      assert {:ok, %DeltaToken{} = dt} =
               Normalizer.delta_token(%{
                 "@odata.deltaLink" =>
                   "https://graph.microsoft.com/v1.0/me/drive/root/delta?token=MzslMjM0"
               })

      assert dt.delta_link =~ "graph.microsoft.com"
      assert is_nil(dt.delta_token)
    end

    test "normalizes an empty envelope" do
      assert {:ok, %DeltaToken{}} = Normalizer.delta_token(%{})
    end

    test "rejects malformed delta token payloads" do
      assert {:error, :invalid_delta_token_payload} = Normalizer.delta_token(:bad)
    end
  end

  # ── Download ──────────────────────────────────────────────────────────

  describe "download/1" do
    test "normalizes download metadata from a drive item with download URL" do
      assert {:ok, %Download{} = dl} =
               Normalizer.download(%{
                 "@content.downloadUrl" => "https://contoso.sharepoint.com/download/01ABCD1234",
                 "size" => 204_800,
                 "file" => %{"mimeType" => "image/jpeg"}
               })

      assert dl.download_url =~ "contoso.sharepoint.com"
      assert dl.content_length == 204_800
      assert dl.content_type == "image/jpeg"
    end

    test "normalizes download metadata with minimal fields" do
      assert {:ok, %Download{} = dl} =
               Normalizer.download(%{
                 "@content.downloadUrl" => "https://example.com/file"
               })

      assert dl.download_url =~ "example.com"
      assert is_nil(dl.content_length)
    end

    test "rejects malformed download payloads" do
      assert {:error, :invalid_download_payload} = Normalizer.download(:bad)
    end
  end

  # ── Paging envelope ───────────────────────────────────────────────────

  describe "page/2" do
    test "extracts normalized drive items from a Graph list envelope" do
      envelope = %{
        "value" => [
          %{"id" => "01A", "name" => "File1.txt"},
          %{"id" => "01B", "name" => "File2.txt"}
        ],
        "@odata.nextLink" => "https://graph.microsoft.com/v1.0/me/drive/root/children?$skip=25"
      }

      assert {:ok, %{items: items, next_link: next}} =
               Normalizer.page(envelope, &Normalizer.drive_item/1)

      assert length(items) == 2
      assert [%DriveItem{name: "File1.txt"}, %DriveItem{name: "File2.txt"}] = items
      assert next =~ "$skip=25"
    end

    test "handles empty value array" do
      envelope = %{"value" => []}

      assert {:ok, %{items: [], next_link: nil}} =
               Normalizer.page(envelope, &Normalizer.drive_item/1)
    end

    test "returns error for malformed envelope" do
      assert {:error, :invalid_page_envelope} =
               Normalizer.page(:bad, &Normalizer.drive_item/1)

      assert {:error, :invalid_page_envelope} =
               Normalizer.page(nil, &Normalizer.drive_item/1)
    end
  end

  # ── Batch helpers ─────────────────────────────────────────────────────

  describe "normalize_list/2" do
    test "normalizes multiple drive items" do
      payloads = [
        %{"id" => "01A", "name" => "File1.txt"},
        %{"id" => "01B", "name" => "File2.txt"}
      ]

      assert {:ok, [item1, item2]} =
               Normalizer.normalize_list(payloads, &Normalizer.drive_item/1)

      assert item1.name == "File1.txt"
      assert item2.name == "File2.txt"
    end

    test "returns error for invalid list" do
      assert {:error, :invalid_list_payloads} =
               Normalizer.normalize_list(:bad, &Normalizer.drive_item/1)
    end
  end

  # ── Struct constructor contracts ──────────────────────────────────────

  describe "struct defaults and validation" do
    test "Drive struct requires drive_id" do
      assert {:error, _error} = Drive.new(%{})
      assert {:ok, %Drive{} = drive} = Drive.new(%{drive_id: "b!DRIVE1"})
      assert drive.metadata == %{}
    end

    test "DriveItem struct requires item_id" do
      assert {:error, _error} = DriveItem.new(%{})

      assert {:ok, %DriveItem{} = item} = DriveItem.new(%{item_id: "01ABCD"})
      assert item.thumbnails == []
      assert item.permissions == []
      assert item.metadata == %{}
    end

    test "Folder struct allows empty attrs" do
      assert {:ok, %Folder{} = folder} = Folder.new(%{})
      assert folder.metadata == %{}
    end

    test "FileFacet struct allows empty attrs" do
      assert {:ok, %FileFacet{} = file} = FileFacet.new(%{})
      assert file.metadata == %{}
    end

    test "Thumbnail struct allows empty attrs" do
      assert {:ok, %Thumbnail{} = thumb} = Thumbnail.new(%{})
      assert thumb.metadata == %{}
    end

    test "SharingLink struct allows empty attrs" do
      assert {:ok, %SharingLink{} = link} = SharingLink.new(%{})
      assert link.metadata == %{}
    end

    test "Permission struct requires permission_id" do
      assert {:error, _error} = Permission.new(%{})

      assert {:ok, %Permission{} = perm} =
               Permission.new(%{permission_id: "PERM1"})

      assert perm.roles == []
      assert perm.granted_to_identities == []
      assert perm.metadata == %{}
    end

    test "DeltaToken struct allows empty attrs" do
      assert {:ok, %DeltaToken{} = dt} = DeltaToken.new(%{})
      assert dt.metadata == %{}
    end

    test "Download struct allows empty attrs" do
      assert {:ok, %Download{} = dl} = Download.new(%{})
      assert dl.metadata == %{}
    end

    test "all structs expose schema/0, new/1, new!/1" do
      for module <- [
            Drive,
            DriveItem,
            Folder,
            FileFacet,
            Thumbnail,
            SharingLink,
            Permission,
            DeltaToken,
            Download
          ] do
        assert function_exported?(module, :schema, 0)
        assert function_exported?(module, :new, 1)
        assert function_exported?(module, :new!, 1)
      end
    end
  end
end
