defmodule Jido.Connect.Google.Drive.PartialFieldsTest do
  use ExUnit.Case, async: false

  alias Jido.Connect
  alias Jido.Connect.Google.Drive
  alias Jido.Connect.TestSupport.LiveSmoke

  # Caller projections without `name`, as the live tests sent them. Drive
  # returns only the requested fields.
  @fields_without_name "id,mimeType,parents,starred,modifiedTime"
  @change_fields_without_name "nextPageToken,newStartPageToken," <>
                                "changes(fileId,removed,time,changeType,driveId," <>
                                "file(id,mimeType,parents,trashed))"
  @folder_fields_without_name "id,mimeType,parents"

  # The starred file of the test account and its folder.
  @starred_file_id "1JphxvbpUOuOhN326OEz9UnJqtAy99n4l"
  @starred_folder_id "18wQ5cSzJVV4Hpxmx_okyZi1-Oo1T10wy"

  # The upload folder, and the file and the folder the live tests created in
  # it and deleted again.
  @upload_folder_id "115ptv8wqbkEFu-3aaOqGiRda0uPYH4I1"
  @unnamed_file_id "1iFcqHz1sbvegITII8IRIotrxq_pWyOkc"
  @unnamed_folder_id "14GnLp4MWGCouR9CPg6ZVLiqfuCJltnl0"

  @checkpoint "stored-checkpoint"

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

  test "google.drive.file.get returns a file whose fields leave out name" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.request_path == "/v3/files/#{@starred_file_id}"
      assert conn.query_params["fields"] == @fields_without_name
      Req.Test.json(conn, LiveSmoke.fixture!(:google_drive, "file_get_without_name"))
    end)

    assert {:ok, %{file: file}} =
             invoke("google.drive.file.get", %{
               file_id: @starred_file_id,
               fields: @fields_without_name
             })

    assert %{
             file_id: @starred_file_id,
             name: nil,
             mime_type: "text/plain",
             parents: [@starred_folder_id],
             starred?: true,
             modified_time: "2026-10-30T15:29:45.332Z"
           } = file
  end

  test "google.drive.file.changed returns file metadata whose fields leave out name" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.request_path == "/v3/changes"
      assert conn.query_params["pageToken"] == @checkpoint
      assert conn.query_params["fields"] == @change_fields_without_name
      Req.Test.json(conn, LiveSmoke.fixture!(:google_drive, "file_changed_without_name"))
    end)

    assert {:ok, %{signals: [signal], checkpoint: "234"}} =
             poll("google.drive.file.changed", %{fields: @change_fields_without_name})

    assert %{
             file_id: @unnamed_file_id,
             removed: false,
             change_type: "file",
             file: %{
               file_id: @unnamed_file_id,
               name: nil,
               mime_type: "text/plain",
               parents: [@upload_folder_id]
             }
           } = signal
  end

  # Caller fields that keep only `removed` leave no field that names a file, a
  # drive or a time. The page is the recorded mixed page projected on what
  # these fields ask for: `newStartPageToken` and each change's `removed`.
  test "google.drive.file.changed returns no signal for changes that keep only removed" do
    fields = "nextPageToken,newStartPageToken,changes(removed)"
    recorded = LiveSmoke.fixture!(:google_drive, "file_changed_mixed")

    page = %{
      "newStartPageToken" => recorded["newStartPageToken"],
      "changes" => Enum.map(recorded["changes"], &Map.take(&1, ["removed"]))
    }

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.request_path == "/v3/changes"
      assert conn.query_params["fields"] == fields
      Req.Test.json(conn, page)
    end)

    assert {:ok, %{signals: [], checkpoint: "113"}} =
             poll("google.drive.file.changed", %{fields: fields})
  end

  # Drive creates the folder before it answers, so a failed answer would
  # report a folder that exists as not created.
  test "google.drive.folder.create returns a folder whose fields leave out name" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/files"
      assert conn.query_params["fields"] == @folder_fields_without_name

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert %{
               "name" => "jcl-live unnamed folder",
               "mimeType" => "application/vnd.google-apps.folder",
               "parents" => [@upload_folder_id]
             } = Jason.decode!(body)

      Req.Test.json(conn, LiveSmoke.fixture!(:google_drive, "folder_create_without_name"))
    end)

    assert {:ok, %{folder: folder}} =
             invoke("google.drive.folder.create", %{
               name: "jcl-live unnamed folder",
               parents: [@upload_folder_id],
               fields: @folder_fields_without_name
             })

    assert %{folder_id: @unnamed_folder_id, name: nil, parents: [@upload_folder_id]} = folder
  end

  defp poll(trigger_id, config) do
    {context, lease} = context_and_lease()

    Connect.poll(Drive.integration(), trigger_id, config,
      context: context,
      credential_lease: lease,
      checkpoint: @checkpoint
    )
  end

  defp invoke(action_id, input) do
    {context, lease} = context_and_lease()

    Connect.invoke(Drive.integration(), action_id, input,
      context: context,
      credential_lease: lease
    )
  end

  defp context_and_lease do
    scopes = [
      "https://www.googleapis.com/auth/drive.metadata.readonly",
      "https://www.googleapis.com/auth/drive.file"
    ]

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

    {context, lease}
  end
end
