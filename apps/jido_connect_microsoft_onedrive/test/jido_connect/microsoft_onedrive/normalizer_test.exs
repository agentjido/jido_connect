defmodule Jido.Connect.MicrosoftOnedrive.NormalizerTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.MicrosoftOnedrive.Normalizer

  # ── Drive Item ────────────────────────────────────────────────────────

  describe "drive_item/1" do
    test "normalizes a Microsoft Graph driveItem payload" do
      assert {:ok, item} =
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
      assert item.folder["childCount"] == 5
      assert item.parent_reference["driveId"] == "b!DRIVE1"
    end

    test "normalizes a drive item with minimal fields" do
      assert {:ok, item} =
               Normalizer.drive_item(%{
                 "id" => "01MINIMAL",
                 "name" => "Notes.txt"
               })

      assert item.item_id == "01MINIMAL"
      assert item.name == "Notes.txt"
      refute Map.has_key?(item, :size)
      refute Map.has_key?(item, :folder)
    end

    test "normalizes a file drive item" do
      assert {:ok, item} =
               Normalizer.drive_item(%{
                 "id" => "01FILE123",
                 "name" => "photo.jpg",
                 "file" => %{"mimeType" => "image/jpeg"}
               })

      assert item.item_id == "01FILE123"
      assert item.file["mimeType"] == "image/jpeg"
      refute Map.has_key?(item, :folder)
    end

    test "rejects malformed drive item payloads" do
      assert {:error, :invalid_drive_item_payload} = Normalizer.drive_item(:bad)
      assert {:error, :invalid_drive_item_payload} = Normalizer.drive_item(nil)
    end
  end

  # ── Drive ─────────────────────────────────────────────────────────────

  describe "drive/1" do
    test "normalizes a Microsoft Graph drive payload" do
      assert {:ok, drive} =
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

    test "normalizes a drive with minimal fields" do
      assert {:ok, drive} =
               Normalizer.drive(%{"id" => "b!MIN", "driveType" => "business"})

      assert drive.drive_id == "b!MIN"
      assert drive.drive_type == "business"
      refute Map.has_key?(drive, :name)
    end

    test "rejects malformed drive payloads" do
      assert {:error, :invalid_drive_payload} = Normalizer.drive(:bad)
      assert {:error, :invalid_drive_payload} = Normalizer.drive(nil)
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
      assert [%{name: "File1.txt"}, %{name: "File2.txt"}] = items
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
end
