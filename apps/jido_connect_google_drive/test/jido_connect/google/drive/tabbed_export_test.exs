defmodule Jido.Connect.Google.Drive.TabbedExportTest do
  use ExUnit.Case, async: false

  alias Jido.Connect
  alias Jido.Connect.Google.Drive
  alias Jido.Connect.TestSupport.LiveSmoke

  # The recording exports the prepared Google Doc with the top-level tabs
  # First and Second and the tab Nested under Second, each holding one seed
  # marker, as plain text under a drive-only grant.
  @document_id "1Ej83l690dmUeDhX90Suxdef_SR97A-Kleilmdg5G9_E"
  @drive_scope "https://www.googleapis.com/auth/drive"

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(
      :jido_connect_google_drive,
      :google_drive_api_base_url,
      "https://drive.test"
    )

    Application.put_env(:jido_connect_google, :google_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:jido_connect_google_drive, :google_drive_api_base_url)
      Application.delete_env(:jido_connect_google, :google_req_options)
    end)
  end

  test "a plain text export of the tabbed document holds First, Second and Nested in that order" do
    recorded = LiveSmoke.fixture!(:google_drive, "file_export_tabbed_document")

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.request_path == "/v3/files/#{@document_id}/export"
      assert conn.query_params["mimeType"] == "text/plain"

      conn
      |> Plug.Conn.put_resp_content_type("text/plain", nil)
      |> Plug.Conn.resp(200, recorded)
    end)

    assert {:ok, %{file_content: content}} =
             invoke(%{file_id: @document_id, mime_type: "text/plain"})

    # A byte order mark, then the markers of First, Second and Nested with two
    # empty CRLF lines between them and without tab titles. Each tab ends with
    # an empty paragraph, so the empty lines do not show whether Google adds
    # a separator between tabs.
    assert content.content ==
             "\uFEFFjcl-marker-tab-first\r\n\r\n\r\n" <>
               "jcl-marker-tab-second\r\n\r\n\r\n" <>
               "jcl-marker-tab-nested"

    assert %{mime_type: "text/plain", encoding: "utf-8", size: 77} = content
  end

  defp invoke(input) do
    connection =
      Connect.Connection.new!(%{
        id: "conn_1",
        provider: :google,
        profile: :user,
        tenant_id: "tenant_1",
        owner_type: :app_user,
        owner_id: "user_1",
        status: :connected,
        scopes: [@drive_scope]
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
        fields: %{access_token: "token"},
        scopes: [@drive_scope]
      })

    Connect.invoke(Drive.integration(), "google.drive.file.export", input,
      context: context,
      credential_lease: lease
    )
  end
end
