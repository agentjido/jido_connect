defmodule Jido.Connect.Google.Drive.FileExportTest do
  use ExUnit.Case, async: false

  alias Jido.Connect
  alias Jido.Connect.Google.Drive
  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  @apps_script_json "application/vnd.google-apps.script+json"

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

  # The live test imported an Apps Script project into the upload folder and
  # recorded its export; the recorded path ends in the project's ID.
  test "google.drive.file.export returns an Apps Script project's JSON export as its bytes" do
    recorded = recording!("file_export_apps_script")
    "/drive/v3/files/" <> export_path = recorded["request"]["path"]
    file_id = String.replace_suffix(export_path, "/export", "")
    body = recorded["body"]

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v3/files/#{file_id}/export"
      assert conn.query_params["mimeType"] == @apps_script_json

      replay(conn, recorded)
    end)

    assert {:ok, %{file_content: file_content}} =
             export(%{file_id: file_id, mime_type: @apps_script_json})

    assert file_content == %{
             file_id: file_id,
             mime_type: @apps_script_json,
             size: byte_size(body),
             content: body,
             encoding: "utf-8",
             binary: false
           }
  end

  # The whole recording: the replay needs its status and headers.
  defp recording!(name) do
    ConnectorContracts.google_fixture!(:google_drive, "recorded/#{name}.json", __DIR__)
  end

  # Answers with the recorded status, headers and body, leaving out the length
  # and checksum headers, which Plug and Req do not need.
  defp replay(conn, recorded) do
    headers =
      for {name, values} <- Map.drop(recorded["headers"], ["content-length", "x-goog-hash"]),
          do: {name, Enum.join(values, ", ")}

    conn
    |> Plug.Conn.merge_resp_headers(headers)
    |> Plug.Conn.resp(recorded["status"], recorded["body"])
  end

  defp export(input) do
    scopes = ["https://www.googleapis.com/auth/drive.readonly"]

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
        fields: %{access_token: "token"},
        scopes: scopes
      })

    Connect.invoke(Drive.integration(), "google.drive.file.export", input,
      context: context,
      credential_lease: lease
    )
  end
end
