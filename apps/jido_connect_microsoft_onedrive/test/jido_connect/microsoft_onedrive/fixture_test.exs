defmodule Jido.Connect.MicrosoftOnedrive.FixtureTest do
  @moduledoc """
  Normalization tests driven by offline JSON fixtures.

  Each test loads a representative Microsoft Graph payload from the fixture
  directory and asserts that the normalizer produces correct Zoi structs
  without exposing sensitive content (tokens, download URLs, etc.).
  """
  use ExUnit.Case, async: true

  alias Jido.Connect.MicrosoftOnedrive.Normalizer

  alias Jido.Connect.MicrosoftOnedrive.{
    DeltaToken,
    Download,
    Drive,
    DriveItem,
    Permission,
    Thumbnail
  }

  test "normalizes common drive fixture" do
    payload = fixture!("drive_common.json")

    assert {:ok, %Drive{} = drive} = Normalizer.drive(payload)
    assert drive.drive_id == "b!DRIVE1"
    assert drive.drive_type == "personal"
    assert drive.name == "OneDrive"
    assert drive.description == "Personal OneDrive storage"
    assert drive.quota["total"] == 1_099_511_627_776
    assert drive.quota["state"] == "normal"
    assert drive.owner.user.display_name == "Adele Vance"
    assert drive.owner.user.email == "adele@contoso.com"
    assert drive.created_date_time == "2025-01-15T08:00:00Z"
  end

  test "normalizes file drive item fixture" do
    payload = fixture!("drive_item_file.json")

    assert {:ok, %DriveItem{} = item} = Normalizer.drive_item(payload)
    assert item.item_id == "01ABCD1234"
    assert item.name == "Quarterly Report.docx"
    assert item.size == 1024
    assert item.file.mime_type =~ "wordprocessingml"
    assert item.file.hashes["sha1Hash"] == "ABC123"
    assert item.parent_reference["driveId"] == "b!DRIVE1"
    assert item.created_by.user.display_name == "Adele Vance"
    assert item.last_modified_by.user.email == "adele@contoso.com"

    assert [%Thumbnail{id: "0", width: 100, height: 75}] = item.thumbnails

    assert [%Permission{permission_id: "PERM1", roles: ["read"]}] = item.permissions

    assert item.permissions
           |> hd()
           |> Map.get(:granted_to)
           |> Map.get(:user)
           |> Map.get(:display_name) == "Bob Smith"
  end

  test "normalizes folder drive item fixture" do
    payload = fixture!("drive_item_folder.json")

    assert {:ok, %DriveItem{} = item} = Normalizer.drive_item(payload)
    assert item.item_id == "01FOLDER1"
    assert item.name == "Reports"
    assert item.size == 5120
    assert item.folder.child_count == 12
    assert item.folder.view["viewType"] == "thumbnails"
    assert is_nil(item.file)
  end

  test "normalizes permission fixture with sharing link" do
    payload = fixture!("permission_common.json")

    assert {:ok, %Permission{} = perm} = Normalizer.permission(payload)
    assert perm.permission_id == "PERM2"
    assert perm.roles == ["read"]
    assert perm.link.type == "view"
    assert perm.link.prevents_download == true
    assert perm.share_id == "SHARE123"
    assert perm.has_password == false

    assert [%{user: %{display_name: "Carol Davis"}}] = perm.granted_to_identities
  end

  test "normalizes delta response fixture" do
    payload = fixture!("delta_response.json")

    assert {:ok, %DeltaToken{} = dt} = Normalizer.delta_token(payload)
    assert dt.delta_token == "MzslMjM0OyUyMzE7MjM0NTY3"

    assert {:ok, %{items: items}} =
             Normalizer.page(
               %{"value" => payload["value"]},
               &Normalizer.drive_item/1
             )

    assert length(items) == 2
    assert [%DriveItem{name: "Quarterly Report.docx"}, %DriveItem{name: "Budget.xlsx"}] = items
  end

  test "normalizes download item fixture" do
    payload = fixture!("download_item.json")

    assert {:ok, %Download{} = dl} = Normalizer.download(payload)
    assert dl.download_url =~ "contoso-my.sharepoint.com/download"
    assert dl.content_length == 204_800
    assert dl.content_type == "image/jpeg"

    # The download URL is retained in the Download struct for content
    # retrieval. Ensure raw @content.downloadUrl is not on DriveItem structs.
    assert dl.download_url =~ "contoso-my.sharepoint.com/download"
  end

  test "normalizes thumbnail set fixture" do
    payload = fixture!("thumbnail_set.json")

    assert {:ok, thumbnails} =
             Normalizer.normalize_list(payload, &Normalizer.thumbnail/1)

    assert length(thumbnails) == 2

    assert [%Thumbnail{width: 100, height: 75}, %Thumbnail{width: 800, height: 600}] =
             thumbnails

    assert Enum.all?(thumbnails, &(&1.source_item_id == "01ABCD1234"))
  end

  # ── Privacy: raw content keys must not survive normalization ──────────

  test "drive item normalization does not leak raw content keys" do
    payload = fixture!("download_item.json")

    assert {:ok, %DriveItem{} = item} = Normalizer.drive_item(payload)
    # @content.downloadUrl must not survive into DriveItem normalization
    refute inspect(item) =~ "@content.downloadUrl"
    refute inspect(item) =~ "tempauth"
    refute Map.has_key?(item, :download_url)
  end

  defp fixture!(name) do
    path =
      Path.join([
        __DIR__,
        "..",
        "..",
        "fixtures",
        "microsoft_onedrive",
        name
      ])

    path
    |> Path.expand()
    |> File.read!()
    |> Jason.decode!()
  end
end
