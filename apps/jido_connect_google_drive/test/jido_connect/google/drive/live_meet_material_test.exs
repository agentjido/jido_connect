defmodule Jido.Connect.Google.Drive.LiveMeetMaterialTest do
  @moduledoc """
  Live checks that read the prepared meeting's recording and notes through
  the Drive content actions.

      mix test --only live_smoke

  `GOOGLE_MEET_RECORDING_FILE_ID` is the Drive file of the prepared Meet
  recording, an MP4 of about 7.7 MB, and `GOOGLE_MEET_NOTES_DOCUMENT_ID` the
  meeting's Gemini notes document, the supplied summary. In the test tenant
  Meet writes the transcript as a tab of that document, titled "Notizen von
  Gemini" in the organizer's locale, so the variable names one shared
  document. If Meet created the transcript and the notes as separate
  documents, the export test would need the notes document. The Meet live
  tests tie both IDs to the conference record, the Calendar live tests to the
  event; see `docs/live_smoke_tests.md`.

  The download is compared with the file's Drive metadata from
  `google.drive.file.get`: the byte count with `size` and the MD5 digest with
  `md5_checksum`. On 2026-11-02 Drive returned no `sha1Checksum` or
  `sha256Checksum` for this file, though it did for the link-shared text file
  of the test account, so MD5 is the only digest Drive offers here. The
  recorded download, `file_download_recording.json`, keeps the byte count and
  SHA-256 digest of the bytes, not the bytes.

  The export is not recorded. Its body is the meeting's notes and transcript,
  account content that the sanitizer does not replace in a plain text body,
  and `file_export.json` already holds a plain text export.
  """

  use ExUnit.Case, async: false
  use Jido.Connect.TestSupport.LiveSmoke

  alias Jido.Connect
  alias Jido.Connect.Google.Drive

  @req_options {:jido_connect_google, :google_req_options}
  @readonly_scope "https://www.googleapis.com/auth/drive.readonly"
  @metadata_fields "id,name,mimeType,size,md5Checksum"

  # Compared without the content, so a failure does not print the file.
  @content_kind [:file_id, :mime_type, :encoding, :binary]

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_MEET_RECORDING_FILE_ID"])
  @tag timeout: :timer.minutes(2)
  test "downloads the meeting recording with the byte count and MD5 digest of its metadata", %{
    env: env
  } do
    token = env["GOOGLE_ACCESS_TOKEN"]
    file_id = env["GOOGLE_MEET_RECORDING_FILE_ID"]

    assert {:ok, %{file: file}} =
             invoke("google.drive.file.get", %{file_id: file_id, fields: @metadata_fields}, token)

    assert file.mime_type == "video/mp4"

    LiveSmoke.record(@req_options, :google_drive, "file_download_recording")

    assert {:ok, %{file_content: content}} =
             invoke("google.drive.file.download", %{file_id: file_id}, token)

    assert Map.take(content, @content_kind) ==
             %{file_id: file_id, mime_type: "video/mp4", encoding: "base64", binary: true}

    bytes = Base.decode64!(content.content_base64)

    assert byte_size(bytes) == content.size
    assert content.size == file.size
    assert md5(bytes) == file.md5_checksum
  end

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_MEET_NOTES_DOCUMENT_ID"])
  test "exports the meeting notes document as plain text", %{env: env} do
    file_id = env["GOOGLE_MEET_NOTES_DOCUMENT_ID"]

    assert {:ok, %{file_content: content}} =
             invoke(
               "google.drive.file.export",
               %{file_id: file_id, mime_type: "text/plain"},
               env["GOOGLE_ACCESS_TOKEN"]
             )

    assert Map.take(content, @content_kind) ==
             %{file_id: file_id, mime_type: "text/plain", encoding: "utf-8", binary: false}

    assert content.size > 0
    assert byte_size(content.content) == content.size
  end

  defp md5(bytes), do: :md5 |> :crypto.hash(bytes) |> Base.encode16(case: :lower)

  defp invoke(action_id, input, access_token) do
    connection =
      Connect.Connection.new!(%{
        id: "live_drive",
        provider: :google,
        profile: :user,
        tenant_id: "live_drive",
        owner_type: :app_user,
        owner_id: "live_drive",
        status: :connected,
        scopes: [@readonly_scope]
      })

    context =
      Connect.Context.new!(%{
        tenant_id: "live_drive",
        actor: %{id: "live_drive", type: :user},
        connection: connection
      })

    lease =
      Connect.CredentialLease.new!(%{
        connection_id: connection.id,
        provider: :google,
        profile: :user,
        expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
        fields: %{access_token: access_token},
        scopes: [@readonly_scope]
      })

    Connect.invoke(Drive.integration(), action_id, input,
      context: context,
      credential_lease: lease
    )
  end
end
