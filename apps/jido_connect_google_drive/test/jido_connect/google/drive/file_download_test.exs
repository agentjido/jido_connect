defmodule Jido.Connect.Google.Drive.FileDownloadTest do
  use ExUnit.Case, async: false

  alias Jido.Connect
  alias Jido.Connect.Google.Drive
  alias Jido.Connect.Google.TestSupport.ConnectorContracts

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

  # The live test uploaded both JSON files as `application/json` and recorded
  # their downloads; each recorded path ends in the uploaded file's ID.
  for kind <- ["object", "array"] do
    test "google.drive.file.download returns a JSON #{kind} file's recorded bytes as file_content" do
      recorded = recording!("file_download_json_#{unquote(kind)}")
      "/drive/v3/files/" <> file_id = recorded["request"]["path"]
      body = recorded["body"]
      [content_length] = recorded["headers"]["content-length"]

      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/v3/files/#{file_id}"
        assert conn.query_params["alt"] == "media"

        replay(conn, recorded)
      end)

      assert {:ok, %{file_content: file_content}} = download(file_id)

      assert file_content == %{
               file_id: file_id,
               mime_type: "application/json",
               size: String.to_integer(content_length),
               content: body,
               encoding: "utf-8",
               binary: false
             }
    end
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

  defp download(file_id) do
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

    Connect.invoke(Drive.integration(), "google.drive.file.download", %{file_id: file_id},
      context: context,
      credential_lease: lease
    )
  end
end
