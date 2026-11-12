defmodule Jido.Connect.Google.Drive.LiveTabbedExportTest do
  @moduledoc """
  Live check that a plain text export of a multi-tab Google Doc holds every
  tab.

      mix test --only live_smoke

  `GOOGLE_DOCS_TABBED_DOCUMENT_ID` has the top-level tabs First and Second
  and the tab Nested under Second, each holding one seed marker. The export
  runs through `google.drive.file.export` with a connection and a lease that
  hold only `drive`, the grant under which the Docs live test reads the same
  document. Google's tokeninfo endpoint confirms, outside the recorder, that
  `GOOGLE_DRIVE_ONLY_ACCESS_TOKEN` holds nothing else.

  The export holds only the seed markers, so it is recorded as
  `file_export_tabbed_document.json`, which `tabbed_export_test.exs` replays.
  """

  use ExUnit.Case, async: false
  use Jido.Connect.TestSupport.LiveSmoke

  alias Jido.Connect
  alias Jido.Connect.Google.Drive

  @req_options {:jido_connect_google, :google_req_options}
  @drive_scope "https://www.googleapis.com/auth/drive"
  @tokeninfo "https://oauth2.googleapis.com/tokeninfo"

  @markers ["jcl-marker-tab-first", "jcl-marker-tab-second", "jcl-marker-tab-nested"]

  @tag env!(["GOOGLE_DRIVE_ONLY_ACCESS_TOKEN", "GOOGLE_DOCS_TABBED_DOCUMENT_ID"])
  test "a plain text export holds the markers of First, Second and Nested in that order", %{
    env: env
  } do
    token = env["GOOGLE_DRIVE_ONLY_ACCESS_TOKEN"]
    file_id = env["GOOGLE_DOCS_TABBED_DOCUMENT_ID"]

    assert token_scopes(token) == [@drive_scope]

    LiveSmoke.record(@req_options, :google_drive, "file_export_tabbed_document")

    assert {:ok, %{file_content: content}} =
             invoke(
               "google.drive.file.export",
               %{file_id: file_id, mime_type: "text/plain"},
               token
             )

    assert %{file_id: ^file_id, mime_type: "text/plain", encoding: "utf-8"} = content

    # The export starts with a byte order mark and ends lines with CRLF. Its
    # lines that are not empty are the markers alone, without tab titles.
    assert "\uFEFF" <> text = content.content
    assert String.split(text, "\r\n", trim: true) == @markers
  end

  # The token goes in the form body, not the URL, and a failure names only
  # the status: Google's answer also carries the OAuth client ID.
  defp token_scopes(access_token) do
    case Req.post!(@tokeninfo, form: [access_token: access_token], retry: false) do
      %{status: 200, body: %{"scope" => scope}} -> String.split(scope)
      %{status: status} -> flunk("tokeninfo answered HTTP #{status}")
    end
  end

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
        scopes: [@drive_scope]
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
        scopes: [@drive_scope]
      })

    Connect.invoke(Drive.integration(), action_id, input,
      context: context,
      credential_lease: lease
    )
  end
end
