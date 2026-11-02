defmodule Jido.Connect.Google.Drive.LiveSmokeTest do
  @moduledoc """
  Live smoke checks against the Google Workspace test account.

      mix test --only live_smoke

  See `docs/live_smoke_tests.md` for the variables and the recording mode.
  """

  use ExUnit.Case, async: false
  use Jido.Connect.TestSupport.LiveSmoke

  alias Jido.Connect
  alias Jido.Connect.Google.Drive
  alias Jido.Connect.Google.Drive.{Client, Link}

  @req_options {:jido_connect_google, :google_req_options}
  @drive_scope "https://www.googleapis.com/auth/drive"
  @shortcut_mime_type "application/vnd.google-apps.shortcut"

  # Account identifiers and the content thumbnail URL that no offline test needs.
  @masked [fields: ["permissionId", "photoLink", "thumbnailLink"]]

  @tag env!(["GOOGLE_ACCESS_TOKEN"])
  test "reads the Drive about resource", %{env: env} do
    LiveSmoke.record(@req_options, :google_drive, "about")

    assert {:ok, about} = Client.get_about(%{}, env["GOOGLE_ACCESS_TOKEN"])
    assert is_map(about)
  end

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_DRIVE_SHARED_LINK_URL", "GOOGLE_DRIVE_SHORTCUT_ID"])
  test "resolves the link-shared file from its URL and reads the shortcut's target", %{env: env} do
    assert {:ok, %{file_id: file_id} = link} = Link.parse(env["GOOGLE_DRIVE_SHARED_LINK_URL"])

    LiveSmoke.record(@req_options, :google_drive, "file_get_shared_link", @masked)

    assert {:ok, %{file: file}} =
             invoke("google.drive.file.get", link, env["GOOGLE_ACCESS_TOKEN"])

    assert file.file_id == file_id
    assert file.resource_key == link[:resource_key]
    assert is_binary(file.mime_type)

    LiveSmoke.record(@req_options, :google_drive, "file_get_shortcut", @masked)

    assert {:ok, %{file: shortcut}} =
             invoke(
               "google.drive.file.get",
               %{file_id: env["GOOGLE_DRIVE_SHORTCUT_ID"]},
               env["GOOGLE_ACCESS_TOKEN"]
             )

    assert shortcut.mime_type == @shortcut_mime_type
    assert shortcut.shortcut_target_id == file.file_id
    assert shortcut.shortcut_target_mime_type == file.mime_type
    assert shortcut.shortcut_target_resource_key == file.resource_key
  end

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_DRIVE_SHARED_LINK_URL"])
  test "downloads the link-shared file from its URL", %{env: env} do
    assert {:ok, %{file_id: file_id} = link} = Link.parse(env["GOOGLE_DRIVE_SHARED_LINK_URL"])

    LiveSmoke.record(@req_options, :google_drive, "file_download", @masked)

    assert {:ok, %{file_content: %{file_id: ^file_id, size: size}}} =
             invoke("google.drive.file.download", link, env["GOOGLE_ACCESS_TOKEN"])

    assert size > 0
  end

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_DRIVE_EDIT_FILE_ID"])
  test "exports the Google Doc as plain text", %{env: env} do
    file_id = env["GOOGLE_DRIVE_EDIT_FILE_ID"]

    LiveSmoke.record(@req_options, :google_drive, "file_export", @masked)

    assert {:ok, %{file_content: %{file_id: ^file_id, mime_type: "text/plain"}}} =
             invoke(
               "google.drive.file.export",
               %{file_id: file_id, mime_type: "text/plain"},
               env["GOOGLE_ACCESS_TOKEN"]
             )
  end

  @tag env!(["GOOGLE_ACCESS_TOKEN"])
  test "a missing file's provider error does not carry the resource key", %{env: env} do
    resource_key = "0-JclLiveSmokeResourceKey"

    LiveSmoke.record(@req_options, :google_drive, "file_get_not_found", @masked)

    assert {:error, %Connect.Error.ProviderError{status: 404} = error} =
             invoke(
               "google.drive.file.get",
               %{file_id: "1JclLiveSmokeMissingFile000000000", resource_key: resource_key},
               env["GOOGLE_ACCESS_TOKEN"]
             )

    refute inspect(error) =~ resource_key
  end

  defp invoke(action_id, input, access_token) do
    connection =
      Connect.Connection.new!(%{
        id: "live_smoke",
        provider: :google,
        profile: :user,
        tenant_id: "live_smoke",
        owner_type: :app_user,
        owner_id: "live_smoke",
        status: :connected,
        scopes: [@drive_scope]
      })

    context =
      Connect.Context.new!(%{
        tenant_id: "live_smoke",
        actor: %{id: "live_smoke", type: :user},
        connection: connection
      })

    lease =
      Connect.CredentialLease.new!(%{
        connection_id: "live_smoke",
        provider: :google,
        profile: :user,
        expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
        fields: %{access_token: access_token},
        scopes: [@drive_scope]
      })

    Connect.invoke(Drive.integration(), action_id, input,
      context: context,
      credential_lease: lease
    )
  end
end
